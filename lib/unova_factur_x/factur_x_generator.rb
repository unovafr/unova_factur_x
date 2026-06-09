module UnovaFacturX
  class FacturXGenerator
    def initialize(pdf:, xml:)
      @pdf = pdf
      @xml = xml
    end

    def call
      # Override HexaPDF default rules to prevent it from forcing PDF version 2.0
      begin
        ::HexaPDF::Type::Catalog.send(:remove_field, :AF)
      rescue StandardError
        nil
      end
      ::HexaPDF::Type::Catalog.define_field :AF, type: ::HexaPDF::PDFArray

      # Generate the XML using the generator
      xml_doc = @xml
      xml_string = xml_doc.to_xml
      xml_io = StringIO.new(xml_string)

      # Convert the PDF into a StringIO object
      pdf_io = @pdf.is_a?(File) ? @pdf : StringIO.new(@pdf)
      pdf_io.rewind

      # Create a new PDF using HexaPDF
      doc = ::HexaPDF::Document.new(io: pdf_io)
      doc.task(:pdfa, level: "3b") # PDF format A/3

      # Attach the XML file to the PDF
      file_spec = doc.files.add(
        xml_io,
        name: "factur-x.xml",
        description: 'Factur-X XML',
        mime_type: 'text/xml',
        )
      file_spec[:AFRelationship] = :Alternative

      doc.catalog[:AF] ||= []
      doc.catalog[:AF] << file_spec

      # Rewrite the metadata to comply with Factur-X requirements
      doc.metadata.custom_metadata(metadata_xml)

      # Return the PDF as a StringIO object
      doc.write_to_string
    end

    private

    def metadata_xml # TODO : Use invoice values
      <<~XML
        <rdf:Description rdf:about=""
                         xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"
                         xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#"
                         xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#">
          <pdfaExtension:schemas>
            <rdf:Bag>
              <rdf:li rdf:parseType="Resource">
                <pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>
                <pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>
                <pdfaSchema:prefix>fx</pdfaSchema:prefix>
                <pdfaSchema:property>
                  <rdf:Seq>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>DocumentType</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>The type of the document</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>DocumentFileName</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>The name of the embedded XML file</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>Version</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>The version of the Factur-X specification</pdfaProperty:description>
                    </rdf:li>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaProperty:name>ConformanceLevel</pdfaProperty:name>
                      <pdfaProperty:valueType>Text</pdfaProperty:valueType>
                      <pdfaProperty:category>external</pdfaProperty:category>
                      <pdfaProperty:description>The conformance level of the Factur-X data</pdfaProperty:description>
                    </rdf:li>
                  </rdf:Seq>
                </pdfaSchema:property>
              </rdf:li>
            </rdf:Bag>
          </pdfaExtension:schemas>
        </rdf:Description>

        <rdf:Description rdf:about=""
                         xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#">
          <fx:DocumentType>INVOICE</fx:DocumentType>
          <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>
          <fx:Version>1.0</fx:Version>
          <fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>
        </rdf:Description>
      XML
    end
  end
end
