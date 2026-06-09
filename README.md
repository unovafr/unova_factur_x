# UnovaFacturX

Factur-X is a hybrid electronic invoice format with a human-readable PDF file that contains, as an attachment, a structured XML file.
This gem allows you to transform invoices and credits notes from the PDF format to the Factur-X format.

## Setup

Add the gem to your gemfile and `bundle install`:
```ruby
gem "unova_factur_x"
```
If you want to use the validator for the generated XML file of the Factur-X, you also need to have Java installed on your computer.

## Usage

Simply call the `generate` method of the gem when you want to send the PDF to the user from your controller.
The method accepts the following parameters:
- pdf: The PDF file of the invoice/credit note to transform to Factur-X. It can be provided in two ways:
  - From a file:
    ```ruby
    path = ActiveStorage::Blob.service.send(:path_for, @invoice.file.key)
    pdf = File.open(path, 'rb')
    ```
  - From a Prawn-generated PDF:
    ```ruby
    pdf = PdfDocument.new(**options).render
    ```
- document_hash: The hash required to generate the XML part of the Factur-X. See below for more details.
- [optional] type: The document type:
  - `:invoice` for an invoice (default value),
  - `:credit` for a credit note,
- [optional] with_validations: `true` or `false`, default as `true`. If true, the generated XML file will be checked using the validator. **WARNING: Java is required for this to work**
- [optional] currency: To configure the used currency (Default is euros 'EUR').
```ruby
# Usage example:
send_data UnovaFacturX.generate(pdf: pdf, document_hash: document_hash, type: :invoice, with_validations: true, currency: "USD"),
          filename: "Factur-X.pdf",
          type: 'application/pdf',
          disposition: 'attachment'
```

### Document hash structure overview


For the expected document hash:
- The document hash is a structured Ruby hash composed of the following main sections:
  - `seller`
  - `buyer`
  - `items`
  - `payment_means`
  - `vat_breakdown`
  - `totals`
- Provided amounts must be arithmetically consistent; no automatic correction is performed.
- All attributes must be provided as strings.
- Follow the structure below:
```ruby
# Example hash for an invoice (the same applies to a credit note; IMPORTANT: do not use negative values for credit note):
document_hash = {
  id: "Unique invoice number (BT-1) [REQUIRED]",
  issue_date: "Issue date in YYYYMMDD format (BT-2) [REQUIRED]",

  seller: {
    name: "Seller legal name (BT-27) [REQUIRED]",
    legal_id: "Legal identifier (SIREN/SIRET) (BT-30) [OPTIONAL]",
    vat_number: "VAT number including buyer country prefix (e.g. FR123...) (BT-31) [OPTIONAL]",
    address: {
      line1: "Street address (BT-35) [REQUIRED]",
      line2: "Address complement [OPTIONAL]",
      postcode: "Postal code (BT-38) [REQUIRED]",
      city: "City (BT-37) [REQUIRED]",
      country: "ISO 3166-1 alpha-2 country code (BT-40) [REQUIRED]",
    }
  },

  # [REQUIRED BLOCK]
  buyer: {
    id: "Internal customer identifier (BT-46) [OPTIONAL]",
    name: "Customer legal name (BT-44) [REQUIRED]",
    vat_number: "VAT number including buyer country prefix (e.g. FR123...) (BT-48) [OPTIONAL]",
    contact: { # [OPTIONAL]
               name: "Customer contact name (BT-56) [OPTIONAL]",
    },
    address: {
      line1: "Street address (BT-50) [REQUIRED]",
      line2: "Address complement [OPTIONAL]",
      postcode: "Postal code (BT-53) [REQUIRED]",
      city: "City (BT-52) [REQUIRED]",
      country: "ISO 3166-1 alpha-2 country code (BT-55) [REQUIRED]",
    }
  },

  # [OPTIONAL BLOCK]
  delivery: {
    gln: "GLN identifier (schemeID 0088) (BT-71) [OPTIONAL]",
    gln_scheme: "0088: GLN (GS1), 0002: SIRENE (France), 9906: SIRET, 9915: French intra-community VAT, 0060: DUNS [OPTIONAL | REQUIRED IF GLN IS PROVIDED]",
    date: "Actual delivery date in YYYYMMDD format (BT-72) [OPTIONAL]",
    address: {
      line1: "Delivery street address (BT-75) [OPTIONAL]",
      line2: "Delivery address complement [OPTIONAL]",
      postcode: "Delivery postal code (BT-75) [OPTIONAL]",
      city: "Delivery city (BT-74) [OPTIONAL]",
      country: "ISO 3166-1 alpha-2 country code (BT-76) [OPTIONAL]",
    }
  },

  # [REQUIRED BLOCK] (minimum 1 item)
  items: [
    {
      line_id: "Line number (BT-126) [REQUIRED]",
      seller_assigned_id: "Internal product identifier (BT-155) [OPTIONAL]",
      name: "Product/service description (BT-153) [REQUIRED]",
      quantity: "Quantity (BT-129) [REQUIRED]",
      unit_code: "UN/ECE Rec20 unit code (e.g. H87, C62, DAY) (BT-130) [REQUIRED]",
      price_ht: "Net unit price excluding VAT (BT-146) [REQUIRED]",
      vat_rate: "VAT rate (BT-152) [REQUIRED]",
      vat_category: "VAT category (S, Z, E, AE...) (BT-151) [REQUIRED]",
      discount: { # [OPTIONAL]
        total_amount: "Discount amount applicable to the invoice line (BT-136) [OPTIONAL unless discount block is present]",
        percentage: "Discount percentage applicable to the invoice line (BT-138) [OPTIONAL unless discount block is present]",
        # reason OR reason_code [REQUIRED] if block is present
        reason: "Reason for the invoice line discount (BT-139) [OPTIONAL unless discount block is present]",
        reason_code: "Reason code for the invoice line discount (BT-140) [OPTIONAL unless discount block is present]"
      },
      line_total: "Net line amount excluding VAT = Quantity × Net unit price (BT-131)"
    }
  ],

  # [REQUIRED BLOCK]
  payment_means: {
    type_code: "UNCL 4461 code (30 = bank transfer) (BT-81) [REQUIRED]",
    iban: "Beneficiary IBAN (BT-84) [REQUIRED for bank transfer]",
  },

  # [REQUIRED BLOCK]
  vat_breakdown: [
    {
      vat_category: "VAT category (BT-118) [REQUIRED]",
      vat_rate: "VAT rate % (BT-119) [REQUIRED]",
      taxable_amount: "Taxable amount excluding VAT for this rate (BT-116) [REQUIRED]",
      tax_amount: "VAT amount for this rate (BT-117) [REQUIRED]",
      # exemption_reason OR exemption_reason_code [REQUIRED] if vat_category = 'E' (Exempt)
      exemption_reason: "VAT exemption reason (BT-120)",
      exemption_reason_code: "VAT exemption reason code (BT-121)"
    }
  ],

  # [OPTIONAL BLOCK]
  discount: [ # This block is an array with one item per item VAT rate. Therefore, it must have the same length as the vat_breakdown block.
    {
      vat_category: "VAT category (BT-118) [REQUIRED if block is present]",
      vat_rate: "VAT rate % (BT-119) [REQUIRED if block is present]",
      total_amount: "Total discount amount for the VAT rate [REQUIRED if percentage is present]",
      percentage: "Document-level discount percentage if the discount is expressed as a percentage (BT-94) [OPTIONAL]",
      # reason OR reason_code [REQUIRED] if block is present
      reason: "Reason for the document-level discount (BT-97)",
      reason_code: "Reason code for the document-level discount (BT-98)",
    }
  ],

  # [REQUIRED BLOCK]
  totals: {
    line_total_ht: "Total line amount excluding VAT (BT-106) [REQUIRED]",
    total_discount: "Sum of document-level discounts (BT-107) [REQUIRED if discount block is present]",
    tax_basis_total_ht: "Total taxable amount (BT-109) [REQUIRED]",
    tax_total: "Total VAT amount (BT-110) [REQUIRED]",
    grand_total_ttc: "Grand total including VAT (BT-112) [REQUIRED]",
    amount_due: "Amount due for payment (BT-115) [OPTIONAL]",
    # due_date OR description [REQUIRED] if amount_due is defined and positive
    due_date: "Payment due date in YYYYMMDD format (BT-9)",
    description: "Payment terms (BT-20)"
  }
}
```

## Third-Party Components

This gem includes the following third-party component:

- Saxon-HE (XSLT and XQuery processor), developed by Saxonica Limited and licensed under the Mozilla Public License 2.0 (MPL-2.0).

The Saxon-HE JAR is redistributed as-is and remains subject to its original license terms.
A copy of the MPL-2.0 license is included in this repository under the LICENSES directory.

## License

This project is licensed under the Apache License 2.0.

The Apache License 2.0 permits the use, modification, distribution, and commercialization of the software, provided that copyright notices are retained and the terms of the license are respected.

Unless required by applicable law or agreed to in writing, this software is distributed on an "AS IS" basis, without warranties or conditions of any kind, either express or implied.

For the full license terms, refer to the LICENSE file located at the root of the repository or to the official license text: https://www.apache.org/licenses/LICENSE-2.0

Copyright (c) 2026 UNOVA