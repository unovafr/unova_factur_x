module UnovaFacturX
  class XmlGenerator
    # Générateur de fichiers XML de type CrossIndustryInvoice pour facture électronique
    #
    # Cette classe permet de générer dynamiquement un fichier XML structuré selon le standard CII (EN16931), à partir d'un objet ruby.
    # Elle supporte les factures simples (type 380) ainsi que les avoirs (type 381).
    # Les montants fournis doivent être arithmétiquement cohérents, aucune correction automatique n’est effectuée.
    # Aussi, pour plus de simplicité, tous les attributs de la facture/du crédit sont attendus en String.
    # @example
    #   # Générer un XML de facture standard
    #   xml = XmlGenerator.new(invoice).call
    #
    #   # Générer un XML pour un avoir
    #   xml = XmlGenerator.new(credit, type: :credit).call
    #
    #   # Configurer la monnaie utilisée sur la facture
    #   xml = XmlGenerator.new(invoice, devise: "USD") # 'EUR' par défaut
    #
    #   # Exemple de hash pour une facture (Même chose pour un avoir /!\ Ne pas mettre les valeurs de l'avoir en négatif /!\) :
    #   document = {
    #     id: "Numéro unique de facture (BT-1) [OBLIGATOIRE]",
    #     issue_date: "Date d'émission format YYYYMMDD (BT-2) [OBLIGATOIRE]",
    #
    #     seller: {
    #       name: "Nom légal du vendeur (BT-27) [OBLIGATOIRE]",
    #       legal_id: "Identifiant légal (SIREN/SIRET) (BT-30) [OPTIONNEL]",
    #       vat_number: "Numéro TVA avec préfixe pays acheteur (ex: FR123...) (BT-31) [OPTIONNEL]",
    #       address: {
    #         line1: "Rue (BT-35) [OBLIGATOIRE]",
    #         line2: "Complément adresse [OPTIONNEL]",
    #         postcode: "Code postal (BT-38) [OBLIGATOIRE]",
    #         city: "Ville (BT-37) [OBLIGATOIRE]",
    #         country: "Code pays ISO 3166-1 alpha-2 (BT-40) [OBLIGATOIRE]",
    #       }
    #     },
    #
    #     # [BLOC OBLIGATOIRE]
    #     buyer: {
    #       id: "Identifiant interne client (BT-46) [OPTIONNEL]",
    #       name: "Nom légal du client (BT-44) [OBLIGATOIRE]",
    #       vat_number: "Numéro TVA avec préfixe pays acheteur (ex: FR123...) (BT-48) [OPTIONNEL]",
    #       contact: { # [OPTIONNEL]
    #         name: "Nom du contact client (BT-56) [OPTIONNEL]",
    #       },
    #       address: {
    #         line1: "Rue (BT-50) [OBLIGATOIRE]",
    #         line2: "Complément adresse [OPTIONNEL]",
    #         postcode: "Code postal (BT-53) [OBLIGATOIRE]",
    #         city: "Ville (BT-52) [OBLIGATOIRE]",
    #         country: "Code pays ISO 3166-1 alpha-2 (BT-55) [OBLIGATOIRE]",
    #       }
    #     },
    #
    #     # [BLOC OPTIONNEL]
    #     delivery: {
    #       gln: "Identifiant GLN (schemeID 0088) (BT-71) [OPTIONNEL]",
    #       gln_scheme: "0088: GLN (GS1), 0002: SIRENE (France), 9906: SIRET, 9915: TVA intracom FR, 0060:	DUNS [OPTIONNEL | OBLIGATOIRE SI GLN]",
    #       date: "Date réelle de livraison format YYYYMMDD (BT-72) [OPTIONNEL]",
    #       address: {
    #         line1: "Rue livraison (BT-75) [OPTIONNEL]",
    #         line2: "Complément adresse livraison [OPTIONNEL]",
    #         postcode: "Code postal livraison (BT-75) [OPTIONNEL]",
    #         city: "Ville livraison (BT-74) [OPTIONNEL]",
    #         country: "Code pays ISO 3166-1 alpha-2 (BT-76) [OPTIONNEL]",
    #       }
    #     },
    #
    #     # [BLOC OBLIGATOIRE] (minimum 1 item)
    #     items: [
    #       {
    #         line_id: "Numéro de ligne (BT-126) [OBLIGATOIRE]",
    #         seller_assigned_id: "Identifiant interne produit (BT-155) [OPTIONNEL]",
    #         name: "Désignation produit/service (BT-153) [OBLIGATOIRE]",
    #         quantity: "Quantité (BT-129) [OBLIGATOIRE]",
    #         unit_code: "Code unité UN/ECE Rec20 (ex: H87, C62, DAY) (BT-130) [OBLIGATOIRE]",
    #         price_ht: "Prix unitaire net HT (BT-146) [OBLIGATOIRE]",
    #         vat_rate: "Taux TVA (BT-152) [OBLIGATOIRE]",
    #         vat_category: "Catégorie TVA (S, Z, E, AE...) (BT-151) [OBLIGATOIRE]",
    #         discount: { # [OPTIONNEL]
    #           total_amount: "Montant de la remise applicable à la ligne de facture (BT-136) [OPTIONNEL sauf si discount]",
    #           percentage: "Pourcentage de remise applicable à la ligne de facture (BT-138) [OPTIONNEL sauf si discount]",
    #           # reason OU reason_code [OBLIGATOIRE] si bloc présent
    #           reason: "Motif de la remise applicable à la ligne de facture (BT-139) [OPTIONNEL sauf si discount]",
    #           reason_code: "Code de motif de la remise applicable à la ligne de facture (BT-140) [OPTIONNEL sauf si discount]"
    #         }
    #         line_total: "Montant net de la ligne HT = Quantité × Prix unitaire net (BT-131)"
    #       }
    #     ],
    #
    #     # [BLOC OBLIGATOIRE]
    #     payment_means: {
    #       type_code: "Code UNCL 4461 (30 = virement) (BT-81) [OBLIGATOIRE]",
    #       iban: "IBAN bénéficiaire (BT-84) [OBLIGATOIRE si virement]",
    #     },
    #
    #     # [BLOC OBLIGATOIRE]
    #     vat_breakdown: [
    #       {
    #         vat_category: "Catégorie TVA (BT-118) [OBLIGATOIRE]",
    #         vat_rate: "Taux TVA % (BT-119) [OBLIGATOIRE]",
    #         taxable_amount: "Base HT pour ce taux (BT-116) [OBLIGATOIRE]",
    #         tax_amount: "Montant TVA pour ce taux (BT-117) [OBLIGATOIRE]",
    #         # exemption_reason OU exemption_reason_code [OBLIGATOIRE] si vat_category = "E" (Exempt)
    #         exemption_reason: "Motif d'exonération de la TVA (BT-120)",
    #         exemption_reason_code: "Code de motif d'exonération de la TVA (BT-121)"
    #       }
    #     ],
    #
    #     # [BLOC OPTIONNEL]
    #     discount: [ # Ce bloc est un tableau avec un item par taux de TVA d'item. Il doit donc avoir la même longueur que le bloc vat_breakdown
    #       {
    #         vat_category: "Catégorie TVA (BT-118) [OBLIGATOIRE si le bloc est présent]",
    #         vat_rate: "Taux TVA % (BT-119) [OBLIGATOIRE si le bloc est présent]",
    #         total_amount: "Montant total de la remise pour le taux de TVA [OBLIGATOIRE si percentage présent]",
    #         percentage: "% de remise au niveau du document si la remise est en % (BT-94) [OPTIONNEL]",
    #         # reason OU reason_code [OBLIGATOIRE] si bloc présent
    #         reason: "Motif de la remise au niveau du document (BT-97)",
    #         reason_code: "Code de motif de la remise au niveau du document (BT-98)",
    #       }
    #     ],
    #
    #     # [BLOC OBLIGATOIRE]
    #     totals: {
    #       line_total_ht: "Total HT lignes (BT-106) [OBLIGATOIRE]",
    #       total_discount: "Somme des remises au niveau du document (BT-107) [OBLIGATOIRE si bloc discount présent]",
    #       tax_basis_total_ht: "Total bases taxables (BT-109) [OBLIGATOIRE]",
    #       tax_total: "Total TVA (BT-110) [OBLIGATOIRE]",
    #       grand_total_ttc: "Total TTC (BT-112) [OBLIGATOIRE]",
    #       amount_due: "Montant à payer (BT-115) [OPTIONNEL]",
    #       # due_date OU description [OBLIGATOIRE] si amount_due est défini et positif
    #       due_date: "Date due du paiement format YYYYMMDD (BT-9)",
    #       description: "Termes du paiement (BT-20)"
    #     }
    #   }
    #
    # @param document [Hash] Un hash représentant une facture ou un crédit.
    # @param type [Symbol] Type de document : `:invoice` pour une facture normale, `:credit` pour un avoir. (`:invoice` par défaut)
    # @param devise [String] Code ISO 4217
    #
    # @return [Nokogiri::XML::Document] Le document XML généré
    def initialize(document, type: :invoice, devise: "EUR", validate: true)
      @document = document
      @type = type
      @devise = devise
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

      # Retourne le XML
      builder.doc
    end

    private

    def build_exchanged_document_context(xml)
      xml['rsm'].ExchangedDocumentContext do
        xml['ram'].GuidelineSpecifiedDocumentContextParameter do
          xml['ram'].ID("urn:cen.eu:en16931:2017") # Identifiant du type de facture (Ici la norme Européenne)
        end
      end
    end

    def build_exchanged_document(xml)
      xml['rsm'].ExchangedDocument do
        xml['ram'].ID(@document[:id]) # Numéro de la facture BT-1 (Doit être unique/vendeur)
        xml['ram'].TypeCode(@type == :credit ? "381" : "380") # Type de document (380 = facture, 381 = avoir) (BT-3)
        if @document[:issue_date].present?
          xml['ram'].IssueDateTime do
            xml['udt'].DateTimeString(@document[:issue_date], format: "102") # Date d’émission de la facture, format YYYYMMDD (BT-2)
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
      raise StandardError, "Besoin d'au moins un item" if @document[:items].blank?

      @document[:items].each do |item|
        xml['ram'].IncludedSupplyChainTradeLineItem do
          xml['ram'].AssociatedDocumentLineDocument do
            xml['ram'].LineID(item[:line_id]) # Numéro de la ligne (BT-126)
          end
          xml['ram'].SpecifiedTradeProduct do
            xml['ram'].SellerAssignedID(item[:seller_assigned_id]) if item[:seller_assigned_id].present? # Identifiant interne du produit attribué par le vendeur (BT-155)
            xml['ram'].Name(item[:name]) # Désignation du produit/service (BT-153)
          end
          xml['ram'].SpecifiedLineTradeAgreement do
            xml['ram'].NetPriceProductTradePrice do
              xml['ram'].ChargeAmount(item[:price_ht]) # Prix unitaire net HT hors remise (BT-146)
            end
          end
          xml['ram'].SpecifiedLineTradeDelivery do
            xml['ram'].BilledQuantity(item[:quantity], unitCode: item[:unit_code]) # Quantité facturée (BT-129) avec code unité de mesure UN/ECE Rec.20/21 (BT-130)
          end

          xml['ram'].SpecifiedLineTradeSettlement do
            xml['ram'].ApplicableTradeTax do
              xml['ram'].TypeCode("VAT") # Type de taxe (VAT), toujours "VAT" en UE (BT-151)
              xml['ram'].CategoryCode(item[:vat_category]) # Code catégorie TVA de la ligne (BT-151). Une valeur parmi : {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
              xml['ram'].RateApplicablePercent(item[:vat_rate]) # Taux de TVA appliqué (%) (BT-152)
            end
            if item[:discount].present?
              discount = item[:discount]
              xml['ram'].SpecifiedTradeAllowanceCharge do
                xml['ram'].ChargeIndicator do
                  xml['udt'].Indicator("false") # true = charge (frais supplémentaires), false = allowance (réduction/remise)
                end
                xml['ram'].CalculationPercent(discount[:percentage]) if discount[:percentage].present? # Pourcentage de remise applicable à la ligne de facture (BT-138)
                xml['ram'].ActualAmount(discount[:total_amount]) # Montant de la remise applicable à la ligne de facture (BT-136)
                xml['ram'].Reason(discount[:reason]) if discount[:reason].present? # Motif de la remise applicable à la ligne de facture (BT-139)
                xml['ram'].ReasonCode(discount[:reason_code]) if discount[:reason_code].present? # Code de motif de la remise applicable à la ligne de facture (BT-140)
                # xml['ram'].BasisAmount(discount[:base]) # Assiette de la remise applicable à la ligne de facture (BT-137)
              end
            end
            xml['ram'].SpecifiedTradeSettlementLineMonetarySummation do
              xml['ram'].LineTotalAmount(item[:line_total]) # Montant net de la ligne HT = Quantité × Prix unitaire net (BT-131)
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
          xml['ram'].GlobalID(delivery[:gln], schemeID: delivery[:gln_scheme]) if delivery[:gln].present? && delivery[:gln_scheme].present? # Identifiant global du lieu de livraison (BT-71) (optionnel) | schemeID -> 0088: GLN (GS1), 0002: SIRENE (France), 9906: SIRET, 9915: TVA intracom FR, 0060:	DUNS

          if delivery[:address].present?
            address = delivery[:address]
            xml['ram'].PostalTradeAddress do
              xml['ram'].PostcodeCode(address[:postcode]) if address[:postcode].present? # Code postal
              xml['ram'].LineOne(address[:line1]) if address[:line1].present? # Rue
              xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Complément
              xml['ram'].CityName(address[:city]) if address[:city].present? # Ville
              xml['ram'].CountryID(address[:country]) if address[:country].present? # Code pays
            end
          end
        end
        if delivery[:date].present?
          xml['ram'].ActualDeliverySupplyChainEvent do
            xml['ram'].OccurrenceDateTime do
              xml['udt'].DateTimeString(delivery[:date], format: "102") # Date effective de livraison, format YYYYMMDD (BT-72)
            end
          end
        end
      end
    end

    def build_applicable_header_trade_agreement(xml)
      xml['ram'].ApplicableHeaderTradeAgreement do
        xml['ram'].SellerTradeParty do
          seller = @document[:seller]
          xml['ram'].Name(seller[:name]) # Nom légal du vendeur (BT-27)
          xml['ram'].SpecifiedLegalOrganization do
            xml['ram'].ID(seller[:legal_id]) # Identifiant légal du vendeur (SIREN/SIRET ou équivalent) (BT-30)
          end
          xml['ram'].PostalTradeAddress do
            address = seller[:address]
            xml['ram'].PostcodeCode(address[:postcode]) # Code postal
            xml['ram'].LineOne(address[:line1]) # Rue
            xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Complément
            xml['ram'].CityName(address[:city]) # Ville
            xml['ram'].CountryID(address[:country]) # Code pays
          end
          if seller[:vat_number].present?
            xml['ram'].SpecifiedTaxRegistration do
              xml['ram'].ID(seller[:vat_number], schemeID: "VA") # Numéro TVA vendeur (BT-31)
            end
          end
        end
        xml['ram'].BuyerTradeParty do
          buyer = @document[:buyer]
          xml['ram'].ID(buyer[:id]) # Identifiant du client (BT-46)
          xml['ram'].Name(buyer[:name]) # Nom légal de l'entreprise cliente (BT-44)
          if buyer[:contact].present?
            contact = buyer[:contact]
            xml['ram'].DefinedTradeContact do
              xml['ram'].PersonName(contact[:name]) # Nom du contact chez le client (BT-56) (optionnel)
            end
          end
          xml['ram'].PostalTradeAddress do
            address = buyer[:address]
            xml['ram'].PostcodeCode(address[:postcode]) # Code postal
            xml['ram'].LineOne(address[:line1]) # Rue
            xml['ram'].LineTwo(address[:line2]) if address[:line2].present? # Complément
            xml['ram'].CityName(address[:city]) # Ville
            xml['ram'].CountryID(address[:country]) # Code pays
          end
          if buyer[:vat_number].present?
            xml['ram'].SpecifiedTaxRegistration do
              xml['ram'].ID(buyer[:vat_number], schemeID: "VA") # Numéro TVA vendeur (BT-48)
            end
          end
        end
      end
    end

    def build_applicable_header_trade_settlement(xml)
      xml['ram'].ApplicableHeaderTradeSettlement do
        payment = @document[:payment_means]
        # xml['ram'].PaymentReference("XXXX") # Référence de paiement (ex : référence virement) (BT-83)
        xml['ram'].InvoiceCurrencyCode(@devise)
        xml['ram'].SpecifiedTradeSettlementPaymentMeans do
          xml['ram'].TypeCode(payment[:type_code]) # Code moyen de paiement UNCL 4461 (BT-81)
          if %w[30 49].include?(payment[:type_code].to_s) && payment[:iban].present? # 30 : Virement, 49 : Prélèvement automatique
            xml['ram'].PayeePartyCreditorFinancialAccount do
              xml['ram'].IBANID(payment[:iban]) # IBAN du compte bénéficiaire (BT-84)
            end
          end
        end
        @document[:vat_breakdown].each do |vat|
          xml['ram'].ApplicableTradeTax do
            xml['ram'].CalculatedAmount(vat[:tax_amount]) # Montant total de TVA pour le taux concerné (BT-117)
            xml['ram'].TypeCode("VAT") # TVA
            xml['ram'].ExemptionReason(vat[:exemption_reason]) if vat[:vat_category] == "E" && vat[:exemption_reason].present? # Motif d'exonération de la TVA (BT-120)
            xml['ram'].ExemptionReasonCode(vat[:exemption_reason_code]) if vat[:vat_category] == "E" && vat[:exemption_reason_code].present? # Code de motif d'exonération de la TVA (BT-121)
            xml['ram'].BasisAmount(vat[:taxable_amount]) # Base taxable HT pour le taux concerné (BT-116)
            xml['ram'].CategoryCode(vat[:vat_category]) # Code catégorie TVA du breakdown (BT-118). Une valeur parmi : {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
            xml['ram'].RateApplicablePercent(vat[:vat_rate]) # Taux de TVA appliqué (%) (BT-119)
          end
        end

        if @document[:discount].present?
          @document[:discount].each do |discount|
            xml['ram'].SpecifiedTradeAllowanceCharge do
              xml['ram'].ChargeIndicator do
                xml['udt'].Indicator("false") # true = charge (frais supplémentaires), false = allowance (réduction/remise)
              end
              xml['ram'].CalculationPercent(discount[:percentage]) if discount[:percentage].present? # % de remise au niveau du document si la remise est en % (BT-94)
              xml['ram'].ActualAmount(discount[:total_amount]) # Montant de la remise au niveau du document pour le taux TVA concerné (BT-92)
              xml['ram'].Reason(discount[:reason]) if discount[:reason].present? # Motif de la remise au niveau du document (BT-97)
              xml['ram'].ReasonCode(discount[:reason_code]) if discount[:reason_code].present? # Code de motif de la remise au niveau du document (BT-98)
              # xml['ram'].BasisAmount(discount[:base]) # Base sur laquelle la remise est appliquée au niveau du document pour le taux TVA concerné (BT-93)
              xml['ram'].CategoryTradeTax do
                xml['ram'].TypeCode("VAT") # Code de type de TVA de la remise (BT-95)
                xml['ram'].CategoryCode(discount[:vat_category]) # Code catégorie TVA (BT-118). Une valeur parmi : {'A', 'AA', 'AB', 'AC', 'AD', 'AE', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'O', 'S', 'Z'}
                xml['ram'].RateApplicablePercent(discount[:vat_rate]) # Taux de TVA appliqué (%) (BT-119)
              end
              # xml['ram'].RateApplicablePercent("0.00") # Taux de TVA de la remise au niveau du document (BT-96)
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
            xml['ram'].Description(totals[:description]) if totals[:description].present? # Payment terms (BT-20)
          end
        end
        xml['ram'].SpecifiedTradeSettlementHeaderMonetarySummation do
          xml['ram'].LineTotalAmount(totals[:line_total_ht]) # Total HT des lignes sans discounts (BT-106)
          xml['ram'].AllowanceTotalAmount(totals[:total_discount]) if @document[:discount].present? && totals[:total_discount].present? # Somme des remises au niveau du document (BT-107)
          xml['ram'].TaxBasisTotalAmount(totals[:tax_basis_total_ht]) # Total des bases taxables HT (avec discounts) (BT-109)
          xml['ram'].TaxTotalAmount(totals[:tax_total], currencyID: @devise) # Montant total de TVA (BT-110)
          xml['ram'].GrandTotalAmount(totals[:grand_total_ttc]) # Total TTC (BT-112)
          xml['ram'].DuePayableAmount(totals[:amount_due]) if totals[:amount_due].present? # Montant restant dû (BT-115)
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

      # Écrit le XML dans un fichier temp
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

      raise "Java non disponible" unless status.exitstatus != 127

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

      raise "EN16931 validation échouée :\n#{messages.join("\n")}"
    end
  end
end
