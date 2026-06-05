# UnovaFacturX

Gem permettant la génération de factures et d'avoirs au format Factur-X.

## Installation

Ajouter la gem au gemfile et faire un ```bundle install```
```ruby
gem "unova_factur_x", git: "git@gitlab.unova.fr:unova-factur-x/unova-factur-x.git"
```

## Utilisation

Il suffit d'appeler la fonction generate de la gem à l'envoi du PDF par le controller avec les paramètres suivants :
- pdf: Le fichier PDF de la facture/avoir à transformer en Factur-X.
- document_hash: Le hash d'entrée pour la génération du XML, voir ci-après pour plus de détails.
- [optionnel] type: Le type de document (:invoice par défaut):
  - :invoice pour une facture,
  - :credit pour un avoir,
- [optionnel] with_validations: true ou false, si à true, va essayer de valider les données du hash fourni pour Factur-X /!\ Nécessite Java, à désactiver si Java non présent /!\ (true par défaut)
- [optionnel] devise: pour configurer la monnaie utilisée sur la facture/l'avoir (Euros 'EUR' par défaut).
```ruby
# Exemple d'utilisation :
send_data UnovaFacturX.generate(pdf: pdf, document_hash: document_hash, type: :invoice, with_validations: true, devise: "USD"),
          filename: "Factur-X.pdf",
          type: 'application/pdf',
          disposition: 'attachment'
```

Pour le hash du document attendu :
- Les montants fournis doivent être arithmétiquement cohérents, aucune correction automatique n’est effectuée.
- Tous les attributs de la facture/du crédit sont attendus en String.
- Respecter la forme ci-dessous :
```ruby
# Exemple de hash pour une facture (Même chose pour un avoir /!\ Ne pas mettre les valeurs de l'avoir en négatif /!\) :
document_hash = {
    id: "Numéro unique de facture (BT-1) [OBLIGATOIRE]",
    issue_date: "Date d'émission format YYYYMMDD (BT-2) [OBLIGATOIRE]",
    
    seller: {
      name: "Nom légal du vendeur (BT-27) [OBLIGATOIRE]",
      legal_id: "Identifiant légal (SIREN/SIRET) (BT-30) [OPTIONNEL]",
      vat_number: "Numéro TVA avec préfixe pays acheteur (ex: FR123...) (BT-31) [OPTIONNEL]",
      address: {
        line1: "Rue (BT-35) [OBLIGATOIRE]",
        line2: "Complément adresse [OPTIONNEL]",
        postcode: "Code postal (BT-38) [OBLIGATOIRE]",
        city: "Ville (BT-37) [OBLIGATOIRE]",
        country: "Code pays ISO 3166-1 alpha-2 (BT-40) [OBLIGATOIRE]",
      }
    },
    
    # [BLOC OBLIGATOIRE]
    buyer: {
      id: "Identifiant interne client (BT-46) [OPTIONNEL]",
      name: "Nom légal du client (BT-44) [OBLIGATOIRE]",
      vat_number: "Numéro TVA avec préfixe pays acheteur (ex: FR123...) (BT-48) [OPTIONNEL]",
      contact: { # [OPTIONNEL]
        name: "Nom du contact client (BT-56) [OPTIONNEL]",
      },
      address: {
        line1: "Rue (BT-50) [OBLIGATOIRE]",
        line2: "Complément adresse [OPTIONNEL]",
        postcode: "Code postal (BT-53) [OBLIGATOIRE]",
        city: "Ville (BT-52) [OBLIGATOIRE]",
        country: "Code pays ISO 3166-1 alpha-2 (BT-55) [OBLIGATOIRE]",
      }
    },
    
    # [BLOC OPTIONNEL]
    delivery: {
      gln: "Identifiant GLN (schemeID 0088) (BT-71) [OPTIONNEL]",
      gln_scheme: "0088: GLN (GS1), 0002: SIRENE (France), 9906: SIRET, 9915: TVA intracom FR, 0060:	DUNS [OPTIONNEL | OBLIGATOIRE SI GLN]",
      date: "Date réelle de livraison format YYYYMMDD (BT-72) [OPTIONNEL]",
      address: {
        line1: "Rue livraison (BT-75) [OPTIONNEL]",
        line2: "Complément adresse livraison [OPTIONNEL]",
        postcode: "Code postal livraison (BT-75) [OPTIONNEL]",
        city: "Ville livraison (BT-74) [OPTIONNEL]",
        country: "Code pays ISO 3166-1 alpha-2 (BT-76) [OPTIONNEL]",
      }
    },
    
    # [BLOC OBLIGATOIRE] (minimum 1 item)
    items: [
      {
        line_id: "Numéro de ligne (BT-126) [OBLIGATOIRE]",
        seller_assigned_id: "Identifiant interne produit (BT-155) [OPTIONNEL]",
        name: "Désignation produit/service (BT-153) [OBLIGATOIRE]",
        quantity: "Quantité (BT-129) [OBLIGATOIRE]",
        unit_code: "Code unité UN/ECE Rec20 (ex: H87, C62, DAY) (BT-130) [OBLIGATOIRE]",
        price_ht: "Prix unitaire net HT (BT-146) [OBLIGATOIRE]",
        vat_rate: "Taux TVA (BT-152) [OBLIGATOIRE]",
        vat_category: "Catégorie TVA (S, Z, E, AE...) (BT-151) [OBLIGATOIRE]",
        discount: { # [OPTIONNEL]
          total_amount: "Montant de la remise applicable à la ligne de facture (BT-136) [OPTIONNEL sauf si discount]",
          percentage: "Pourcentage de remise applicable à la ligne de facture (BT-138) [OPTIONNEL sauf si discount]",
          # reason OU reason_code [OBLIGATOIRE] si bloc présent
          reason: "Motif de la remise applicable à la ligne de facture (BT-139) [OPTIONNEL sauf si discount]",
          reason_code: "Code de motif de la remise applicable à la ligne de facture (BT-140) [OPTIONNEL sauf si discount]"
        },
        line_total: "Montant net de la ligne HT = Quantité × Prix unitaire net (BT-131)"
      }
    ],
    
    # [BLOC OBLIGATOIRE]
    payment_means: {
      type_code: "Code UNCL 4461 (30 = virement) (BT-81) [OBLIGATOIRE]",
      iban: "IBAN bénéficiaire (BT-84) [OBLIGATOIRE si virement]",
    },
    
    # [BLOC OBLIGATOIRE]
    vat_breakdown: [
      {
        vat_category: "Catégorie TVA (BT-118) [OBLIGATOIRE]",
        vat_rate: "Taux TVA % (BT-119) [OBLIGATOIRE]",
        taxable_amount: "Base HT pour ce taux (BT-116) [OBLIGATOIRE]",
        tax_amount: "Montant TVA pour ce taux (BT-117) [OBLIGATOIRE]",
        # exemption_reason OU exemption_reason_code [OBLIGATOIRE] si vat_category = "E" (Exempt)
        exemption_reason: "Motif d'exonération de la TVA (BT-120)",
        exemption_reason_code: "Code de motif d'exonération de la TVA (BT-121)"
      }
    ],
    
    # [BLOC OPTIONNEL]
    discount: [ # Ce bloc est un tableau avec un item par taux de TVA d'item. Il doit donc avoir la même longueur que le bloc vat_breakdown
      {
        vat_category: "Catégorie TVA (BT-118) [OBLIGATOIRE si le bloc est présent]",
        vat_rate: "Taux TVA % (BT-119) [OBLIGATOIRE si le bloc est présent]",
        total_amount: "Montant total de la remise pour le taux de TVA [OBLIGATOIRE si percentage présent]",
        percentage: "% de remise au niveau du document si la remise est en % (BT-94) [OPTIONNEL]",
        # reason OU reason_code [OBLIGATOIRE] si bloc présent
        reason: "Motif de la remise au niveau du document (BT-97)",
        reason_code: "Code de motif de la remise au niveau du document (BT-98)",
      }
    ],
    
    # [BLOC OBLIGATOIRE]
    totals: {
      line_total_ht: "Total HT lignes (BT-106) [OBLIGATOIRE]",
      total_discount: "Somme des remises au niveau du document (BT-107) [OBLIGATOIRE si bloc discount présent]",
      tax_basis_total_ht: "Total bases taxables (BT-109) [OBLIGATOIRE]",
      tax_total: "Total TVA (BT-110) [OBLIGATOIRE]",
      grand_total_ttc: "Total TTC (BT-112) [OBLIGATOIRE]",
      amount_due: "Montant à payer (BT-115) [OPTIONNEL]",
      # due_date OU description [OBLIGATOIRE] si amount_due est défini et positif
      due_date: "Date due du paiement format YYYYMMDD (BT-9)",
      description: "Termes du paiement (BT-20)"
    }
}
```