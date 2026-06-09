module UnovaFacturX
  class XmlGenerator
    # @param document [Hash] A hash representing an invoice or a credit note.
    # @param type [Symbol] Document type: :invoice for a standard invoice, :credit for a credit note (:invoice by default).
    # @param currency [String] ISO 4217 currency code.
    #
    # @return [Nokogiri::XML::Document] The generated XML document
    def initialize(document, type: :invoice, currency: "EUR", validate: true)
      @document = document
      @type = type
      @currency = currency
      @validate = validate
    end

    def call
      builder = ::Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml['rsm'].CrossIndustryInvoice(
          'xmlns:rsm' => 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100',
          'xmlns:udt' => 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100',
          'xmlns:qdt' => 'urn:un:unece:uncefact:data:standard:QualifiedDataType:100',
          'xmlns:ram' => 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100'
        ) do
          build_exchanged_document_context(xml)
          build_exchanged_document(xml)
          build_supply_chain_trade_transaction(xml)
        end
      end

      validate_with_xslt!(builder.doc) if @validate

      # Returns the XML document
      builder.doc
    end

    private

    def build_exchanged_document_context(xml)
      xml['rsm'].ExchangedDocumentContext do
        xml['ram'].GuidelineSpecifiedDocumentContextParameter do
          xml['ram'].ID("urn:cen.eu:en16931:2017") # Identifier of the invoice specification (European EN16931 standard)
        end
      end
    end

    def build_exchanged_document(xml)
      xml['rsm'].ExchangedDocument do
        xml['ram'].ID(@document[:id]) # Invoice number (BT-1) - must be unique per seller
        xml['ram'].TypeCode(@type == :credit ? "381" : "380") # Document type (380 = invoice, 381 = credit note) (BT-3)
        if @document[:issue_date].present?
          xml['ram'].IssueDateTime do
            xml['udt'].DateTimeString(@document[:issue_date], format: "102") # Invoice issue date in YYYYMMDD format (BT-2)
          end
        end
      end
    end

    def build_supply_chain_trade_transaction(xml)
      xml['rsm'].SupplyChainTradeTransaction do
        build_line_items(xml)
        build_applicable_header_trade_agreement(xml)
        build_applicable_header_trade_delivery(xml)
        build_applicable_header_trade_settlement(xml)
      end
    end

    def build_line_items(xml)
      raise StandardError, "At least one item is required" if @document[:items].blank?

      @document[:items].each do |item|
        xml['ram'].IncludedSupplyChainTradeLineItem do
          xml['ram'].AssociatedDocumentLineDocument do
            xml['ram'].LineID(item[:line_id]) # Line number (BT-126)
          end
          xml['ram'].SpecifiedTradeProduct do
            xml['ram'].SellerAssignedID(item[:seller_assigned_id]) if item[:seller_assigned_id].present? # Internal product identifier assigned by the seller (BT-155)
            xml['ram'].Name(item[:name]) # Product/service description (BT-153)
          end
          xml['ram'].SpecifiedLineTradeAgreement do
            xml['ram'].NetPriceProductTradePrice do
              xml['ram'].ChargeAmount(item[:price_ht]) # Net unit price excluding VAT (BT-146)
            end
          end
          xml['ram'].SpecifiedLineTradeDelivery do
            xml['ram'].BilledQuantity(item[:quantity], unitCode: item[:unit_code]) # Quantity invoiced (BT-129) with unit code UN/ECE Rec. 20 (BT-130)
          end

          xml['ram'].SpecifiedLineTradeSettlement do
            xml['ram'].ApplicableTradeTax do
              xml['ram'].TypeCode("VAT") # VAT type (always "VAT" in the EU) (BT-151)
              xml['ram'].CategoryCode(item[:vat_category]) # VAT category code for the line item (BT-151). One among these: {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
              xml['ram'].RateApplicablePercent(item[:vat_rate]) # VAT rate applied (%) (BT-152)
            end
            if item[:discount].present?
              discount = item[:discount]
              xml['ram'].SpecifiedTradeAllowanceCharge do
                xml['ram'].ChargeIndicator do
                  xml['udt'].Indicator("false") # true = charge (additional fees), false = allowance (discount/allowance)
                end
                xml['ram'].CalculationPercent(discount[:percentage]) if discount[:percentage].present? # Discount percentage applicable to the invoice line (BT-138)
                xml['ram'].ActualAmount(discount[:total_amount]) # Discount amount applicable to the invoice line (BT-136)
                xml['ram'].Reason(discount[:reason]) if discount[:reason].present? # Reason for the discount on the invoice line (BT-139)
                xml['ram'].ReasonCode(discount[:reason_code]) if discount[:reason_code].present? # Reason code for the discount on the invoice line (BT-140)
                # xml['ram'].BasisAmount(discount[:base]) # Discount basis applicable to invoice line (BT-137)
              end
            end
            xml['ram'].SpecifiedTradeSettlementLineMonetarySummation do
              xml['ram'].LineTotalAmount(item[:line_total]) # Net line amount excluding VAT = Quantity × Net unit price (BT-131)
            end
          end
        end
      end
    end

    def build_applicable_header_trade_delivery(xml)
      if @document[:delivery].blank?
        xml['ram'].ApplicableHeaderTradeDelivery do
          xml['ram'].ActualDeliverySupplyChainEvent do
            xml['ram'].OccurrenceDateTime do
              xml['udt'].DateTimeString(@document[:issue_date], format: "102")
            end
          end
        end
        return
      end

      delivery = @document[:delivery]

      xml['ram'].ApplicableHeaderTradeDelivery do
        xml['ram'].ShipToTradeParty do
          xml['ram'].GlobalID(delivery[:gln], schemeID: delivery[:gln_scheme]) if delivery[:gln].present? && delivery[:gln_scheme].present? # Global identifier of the delivery location (BT-71)  | Scheme identifiers: 0088: GLN (GS1), 0002: SIRENE (France), 9906: SIRET, 9915: EU VAT number (FR), 0060: DUNS

          if delivery[:address].present?
            address = delivery[:address]
            xml['ram'].PostalTradeAddress do
              xml['ram'].PostcodeCode(address[:postcode]) if address[:postcode].present? # Delivery postal code
              xml['ram'].LineOne(address[:line1]) if address[:line1].present? # Street address
              xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Address complement
              xml['ram'].CityName(address[:city]) if address[:city].present? # City
              xml['ram'].CountryID(address[:country]) if address[:country].present? # Country code
            end
          end
        end
        if delivery[:date].present?
          xml['ram'].ActualDeliverySupplyChainEvent do
            xml['ram'].OccurrenceDateTime do
              xml['udt'].DateTimeString(delivery[:date], format: "102") # Actual delivery date in YYYYMMDD format (BT-72)
            end
          end
        end
      end
    end

    def build_applicable_header_trade_agreement(xml)
      xml['ram'].ApplicableHeaderTradeAgreement do
        xml['ram'].SellerTradeParty do
          seller = @document[:seller]
          xml['ram'].Name(seller[:name]) # Seller legal name (BT-27)
          xml['ram'].SpecifiedLegalOrganization do
            xml['ram'].ID(seller[:legal_id]) # Seller legal identifier (SIREN/SIRET or equivalent) (BT-30)
          end
          xml['ram'].PostalTradeAddress do
            address = seller[:address]
            xml['ram'].PostcodeCode(address[:postcode]) # Postal code
            xml['ram'].LineOne(address[:line1]) # Street address
            xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Address complement
            xml['ram'].CityName(address[:city]) # City
            xml['ram'].CountryID(address[:country]) # Country code
          end
          if seller[:vat_number].present?
            xml['ram'].SpecifiedTaxRegistration do
              xml['ram'].ID(seller[:vat_number], schemeID: "VA") # Seller VAT number (BT-31)
            end
          end
        end
        xml['ram'].BuyerTradeParty do
          buyer = @document[:buyer]
          xml['ram'].ID(buyer[:id]) # Buyer identifier (BT-46)
          xml['ram'].Name(buyer[:name]) # Buyer legal name (BT-44)
          if buyer[:contact].present?
            contact = buyer[:contact]
            xml['ram'].DefinedTradeContact do
              xml['ram'].PersonName(contact[:name]) # Contact name for the buyer (BT-56) 
            end
          end
          xml['ram'].PostalTradeAddress do
            address = buyer[:address]
            xml['ram'].PostcodeCode(address[:postcode]) # Buyer postal code
            xml['ram'].LineOne(address[:line1]) # Street address
            xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Address complement
            xml['ram'].CityName(address[:city]) # City
            xml['ram'].CountryID(address[:country]) # Country code
          end
          if buyer[:vat_number].present?
            xml['ram'].SpecifiedTaxRegistration do
              xml['ram'].ID(buyer[:vat_number], schemeID: "VA") # Buyer VAT number (BT-48)
            end
          end
        end
      end
    end

    def build_applicable_header_trade_settlement(xml)
      xml['ram'].ApplicableHeaderTradeSettlement do
        payment = @document[:payment_means]
        # xml['ram'].PaymentReference("XXXX") # Payment reference (e.g. bank transfer reference) (BT-83)
        xml['ram'].InvoiceCurrencyCode(@currency) # Invoice currency code
        xml['ram'].SpecifiedTradeSettlementPaymentMeans do
          xml['ram'].TypeCode(payment[:type_code]) # Payment method code UNCL 4461 (BT-81)
          if %w[30 49].include?(payment[:type_code].to_s) && payment[:iban].present? # 30: Bank transfer, 49: Direct debit
            xml['ram'].PayeePartyCreditorFinancialAccount do
              xml['ram'].IBANID(payment[:iban]) # Payee IBAN (BT-84)
            end
          end
        end
        @document[:vat_breakdown].each do |vat|
          xml['ram'].ApplicableTradeTax do
            xml['ram'].CalculatedAmount(vat[:tax_amount]) # VAT calculated amount for the given rate (BT-117)
            xml['ram'].TypeCode("VAT") # VAT type (always "VAT" in the EU)
            xml['ram'].ExemptionReason(vat[:exemption_reason]) if vat[:vat_category] == "E" && vat[:exemption_reason].present? # VAT exemption reason (BT-120)
            xml['ram'].ExemptionReasonCode(vat[:exemption_reason_code]) if vat[:vat_category] == "E" && vat[:exemption_reason_code].present? # VAT exemption reason code (BT-121)
            xml['ram'].BasisAmount(vat[:taxable_amount]) # Taxable base amount for the VAT rate (BT-116)
            xml['ram'].CategoryCode(vat[:vat_category]) # VAT category code (BT-118). One among these : {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
            xml['ram'].RateApplicablePercent(vat[:vat_rate]) # VAT rate applied (%) (BT-119)
          end
        end

        if @document[:discount].present?
          @document[:discount].each do |discount|
            xml['ram'].SpecifiedTradeAllowanceCharge do
              xml['ram'].ChargeIndicator do
                xml['udt'].Indicator("false") # true = charge (additional fees), false = allowance (discount/allowance)
              end
              xml['ram'].CalculationPercent(discount[:percentage]) if discount[:percentage].present? # Discount percentage at document level (BT-94)
              xml['ram'].ActualAmount(discount[:total_amount]) # Discount amount at document level for VAT rate (BT-92)
              xml['ram'].Reason(discount[:reason]) if discount[:reason].present? # Reason for document-level discount (BT-97)
              xml['ram'].ReasonCode(discount[:reason_code]) if discount[:reason_code].present? # Reason code for document-level discount (BT-98)
              # xml['ram'].BasisAmount(discount[:base]) # Base amount used for discount calculation (BT-93)
              xml['ram'].CategoryTradeTax do
                xml['ram'].TypeCode("VAT") # VAT type (always "VAT" in the EU) (BT-95)
                xml['ram'].CategoryCode(discount[:vat_category]) # VAT category for discount (BT-118). One among these : {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
                xml['ram'].RateApplicablePercent(discount[:vat_rate]) # VAT rate applied to discount (BT-119)
              end
              # xml['ram'].RateApplicablePercent("0.00") # VAT rate for the document-level discount (BT-96)
            end
          end
        end

        totals = @document[:totals]
        if totals[:amount_due].present? && totals[:amount_due].to_f.positive? && (totals[:due_date].present? || totals[:description].present?)
          xml['ram'].SpecifiedTradePaymentTerms do
            if totals[:due_date].present?
              xml['ram'].DueDateDateTime do
                xml['udt'].DateTimeString(totals[:due_date], format: "102") # Payment due date (BT-9)
              end
            end
            xml['ram'].Description(totals[:description]) if totals[:description].present? # Payment terms description (BT-20)
          end
        end
        xml['ram'].SpecifiedTradeSettlementHeaderMonetarySummation do
          xml['ram'].LineTotalAmount(totals[:line_total_ht]) # Total line amount excluding VAT (BT-106)
          xml['ram'].AllowanceTotalAmount(totals[:total_discount]) if @document[:discount].present? && totals[:total_discount].present? # Total document-level discounts (BT-107)
          xml['ram'].TaxBasisTotalAmount(totals[:tax_basis_total_ht]) # Total taxable base amount (BT-109)
          xml['ram'].TaxTotalAmount(totals[:tax_total], currencyID: @currency) # Total VAT amount (BT-110)
          xml['ram'].GrandTotalAmount(totals[:grand_total_ttc]) # Total amount including VAT (BT-112)
          xml['ram'].DuePayableAmount(totals[:amount_due]) if totals[:amount_due].present? # Amount remaining to be paid (BT-115)
        end
      end
    end

    def validate_with_xslt!(doc)
      xslt_path = File.expand_path(
        "../validators/EN16931-CII-validation.xslt",
        __dir__
      )
      resolver_path = File.expand_path(
        "../java/xmlresolver-5.2.2.jar",
        __dir__
      )
      jar_path = File.expand_path(
        "../java/Saxon-HE-12.4.jar",
        __dir__
      )
      classpath = "#{jar_path}:#{resolver_path}"

      # Writes the XML to a temporary file.
      tmp_xml = Tempfile.new(['invoice', '.xml'])
      tmp_xml.write(doc.to_xml)
      tmp_xml.flush

      stdout, stderr, status = Open3.capture3(
        'java', '-cp', classpath,
        'net.sf.saxon.Transform',
        "-s:#{tmp_xml.path}",
        "-xsl:#{xslt_path}"
      )
      tmp_xml.close
      tmp_xml.unlink

      raise "Java not available" if status.exitstatus == 127

      report = ::Nokogiri::XML(stdout)

      svrl_namespace = { 'svrl' => 'http://purl.oclc.org/dsdl/svrl' }.freeze
      errors = report.xpath(
        '//svrl:failed-assert | //svrl:successful-report',
        svrl_namespace
      )

      return if errors.empty?

      messages = errors.map do |e|
        e.at_xpath('svrl:text', svrl_namespace)&.text&.strip
      end

      raise "EN16931 validation failed:\n#{messages.join("\n")}"
    end
  end
end
