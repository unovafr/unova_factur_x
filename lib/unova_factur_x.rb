# frozen_string_literal: true

require "hexapdf"
require "nokogiri"

require_relative "unova_factur_x/version"
require_relative "unova_factur_x/xml_generator"
require_relative "unova_factur_x/factur_x_generator"

module UnovaFacturX
  class Error < StandardError; end

  def self.generate(pdf:, document_hash:, type: :invoice, with_validations: true, currency: "EUR")
    unless %i[invoice credit].include?(type)
      raise ArgumentError, "Type must be :invoice or :credit (default is :invoice)"
    end

    # Génération du XML à partir du hash en entré
    xml = UnovaFacturX::XmlGenerator.new(document_hash, type: type, validate: with_validations, currency: currency).call

    # Génération et retour du PDF FacturX à partir du PDF en entré et du XML généré
    UnovaFacturX::FacturXGenerator.new(pdf: pdf, xml: xml).call
  end
end
