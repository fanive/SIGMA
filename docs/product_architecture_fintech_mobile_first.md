# SIGMA Invest Learn - Product Architecture Blueprint

## 1) Vision produit
Construire une application mobile-first d'analyse d'actions qui transforme des données financières complexes en compréhension actionnable pour les 12-30 ans, sans surpromesse.

Promesse centrale:
- Comprendre avant d'agir.
- Comparer au lieu de deviner.
- Décider avec contexte, risques et incertitudes.

Positionnement:
- Outil d'aide à la recherche et d'éducation financière.
- Pas de signal d'achat/vente absolu.
- Transparence sur la date des données et le niveau de confiance.

## 2) Personas cibles
Persona A - Lea, 16 ans, debutante:
- Veut comprendre ce qu'est un bon business.
- Besoin: langage simple, glossaire, score explicable.
- Risque: surconfiance apres 2-3 gains.

Persona B - Yanis, 22 ans, intermediaire:
- Compare des actions d'un meme secteur.
- Besoin: KPI compacts, benchmark, scenarios bull/base/bear.
- Risque: biais de confirmation.

Persona C - Sarah, 29 ans, autodidacte:
- Veut une routine de recherche rapide et fiable.
- Besoin: watchlist, alertes, historique these vs realite.
- Risque: surcharge d'information.

## 3) Parcours utilisateur
Parcours principal:
1. Home -> recherche ticker
2. Resultat -> Resume de these + confiance + disclaimer
3. KPI essentiels -> valorisation -> performance -> risques
4. Actualites/catalyseurs + calendrier
5. Scenario bull/base/bear
6. Ajout watchlist

Parcours comparaison:
1. Selection ticker A
2. Selection ticker B du meme secteur (suggestions automatiques)
3. Vue comparee: croissance, marges, rentabilite, valorisation, momentum, risque, qualite
4. Synthese pedagogique: points forts/faibles relatifs

## 4) Fonctionnalites MVP
- Recherche ticker rapide + suggestions
- Fiche entreprise: description, secteur, geographie, taille
- Analyse mono ticker:
  - Fondamentaux: revenus, croissance, marges, EPS, FCF, dette, ROE/ROIC, liquidite
  - Valorisation: P/E, forward P/E, EV/EBITDA, P/S, FCF yield
  - Performance: 1M, 6M, 1Y, 3Y, 5Y
  - Qualite business
  - Risques majeurs
  - News et catalyseurs
  - Calendrier resultats/evenements
  - Score global explicable + sous-scores
  - Scenarios bull/base/bear
  - Sections pedagogiques: Pourquoi investir, Pourquoi eviter, A surveiller
- Comparaison 2 tickers cote a cote
- Benchmark secteur (medianes secteur)
- Glossaire in-app
- Watchlist
- Etats UX: loading skeleton, empty, no-data, error + retry

## 5) Fonctionnalites V2
- Alertes personnalisables (variation, publication resultats, changement score)
- Journal de these utilisateur (avant/apres resultats)
- Coach de biais cognitifs (checklist anti-biais)
- Simulateur d'hypotheses simples (sensibilite croissance/marge)
- Mode classe ou mentorat (professeurs/communautes)
- Export PDF de fiche d'analyse

## 6) Structure de navigation
Navigation bottom bar (mobile):
- Explorer
- Compare
- Watchlist
- Learn (glossaire + mini-cours)
- Profile

Navigation detail ticker:
- Resume
- KPI
- Theses & Risques
- News & Evenements
- Donnees (tableaux detail)

## 7) Architecture des ecrans
1. Splash/Onboarding
2. Home Explorer
3. Search Results
4. Ticker Overview
5. KPI Deep Dive
6. Risk Panel
7. News & Catalysts
8. Earnings & Events Calendar
9. Comparison Screen (A vs B)
10. Sector Benchmark Sheet
11. Watchlist
12. Glossary
13. Settings (theme, langue, disclaimer, sources)

## 8) Composants UI
- SearchBar predictive
- ScoreCard explicable (score + facteurs)
- KpiGrid compact (valeur, variation, interpretation)
- ConfidenceBadge (High/Medium/Low)
- DataFreshnessChip (maj + age des donnees)
- ScenarioCard (Bull/Base/Bear)
- RiskTag (dette, cyclicite, dilution, concentration, macro)
- CompareTable sticky header
- MiniChart de performance multi-horizon
- SourceSheet (provenance des donnees)
- GlossaryTooltip (tap sur terme)
- ComplianceBanner persistent

Design system:
- Mobile-first, AA, touch target >= 44px
- Dark/Light
- Couleurs discretes (pas de rouge/vert agressif)
- Typographie lisible, densite informative moderee

## 9) Modele de donnees
Entites principales:
- TickerProfile
- FundamentalsSnapshot
- ValuationSnapshot
- PerformanceSeries
- QualityAssessment
- RiskAssessment
- CatalystFeedItem
- EarningsEvent
- SectorBenchmark
- ExplainableScore
- ScenarioSet
- ConfidenceMeta
- WatchlistItem
- GlossaryTerm

Principes:
- Toutes les valeurs stockent: valeur, unite, date_maj, source
- Champs explicatifs separes des champs quantitatifs
- Null-safe avec raison de manque (missing_reason)

## 10) Logique d'analyse et de scoring
Score global sur 100 = somme ponderee des sous-scores:
- Croissance (20)
- Rentabilite (20)
- Valorisation relative (20)
- Qualite business (20)
- Risque (20, inverse)

Exemple de regles mesurables:
- Croissance: CAGR revenus/EPS, acceleration ou deceleration
- Rentabilite: marge operationnelle, FCF margin, ROE/ROIC
- Valorisation: percentile secteur de P/E, EV/EBITDA, P/S, FCF yield
- Qualite: stabilite marges, conversion cash, allocation capital
- Risque: leverage, dilution, concentration clients/produits, cyclicite

Chaque sous-score doit produire:
- valeur numerique
- 3 facteurs positifs
- 3 facteurs de fragilite
- confiance (High/Medium/Low)

## 11) Systeme de prompts LLM
Objectif:
- Generer une synthese pedagogique explicable, jamais imperative.

Template system prompt:
- Role: analyste educatif, neutre, prudent.
- Interdits: promesse de rendement, recommandation categorique, certitude excessive.
- Obligation: afficher limites des donnees, date de mise a jour, confiance.

Template user prompt structurant:
- Input: JSON de donnees numeriques + evenements + benchmark secteur
- Output strict:
  - Resume
  - Pourquoi investir
  - Pourquoi eviter
  - A surveiller
  - Bull/Base/Bear
  - Questions de due diligence

Post-processing:
- Filtre de conformite lexical (acheter/vendre imperatif)
- Validation schema JSON
- Injection automatique disclaimer legal

## 12) Garde-fous legaux et ethiques
Regles non negociables:
- Message fixe: Outil d'aide a la recherche, pas un conseil financier.
- Jamais de formulation: Tu dois acheter/vendre.
- Toujours afficher:
  - date/heure de maj
  - sources
  - niveau de confiance
  - limites des donnees
- Journalisation des reponses LLM pour audit interne
- Prevention de surconfiance:
  - scenarios multiples
  - contre-arguments obligatoires

## 13) Stack technique recommandee
Frontend mobile/web mobile:
- Flutter (deja en place)
- State management: Provider (deja en place) ou migration progressive vers Riverpod
- Charts: fl_chart ou Syncfusion si besoin avance

Backend data:
- API principale: sigma-yfinance-api.onrender.com
- Fallback: Finnhub free endpoints cibles
- Caching: Redis (server) + cache local TTL (client)

AI layer:
- Pipeline actuel SigmaService avec fallback providers
- JSON schema validation avant rendu UI

Observabilite:
- Sentry + analytics produit (events de parcours)
- Dashboard qualite donnees (completude par ticker)

## 14) Plan d'implementation en phases
Phase 1 (2-3 semaines):
- Consolider ecran Overview: resume > KPI > these > risques
- Ajouter DataFreshnessChip + ConfidenceBadge + ComplianceBanner
- Uniformiser etats empty/error/no-data

Phase 2 (2-3 semaines):
- Ecran Compare A vs B complet
- Benchmark secteur + sous-scores explicables
- Glossaire contextualise par tooltip

Phase 3 (2 semaines):
- Scenarios bull/base/bear standardises
- Amelioration prompt pipeline + validation schema stricte
- Instrumentation analytics parcours

Phase 4 (2 semaines):
- Watchlist enrichie + alertes evenements
- Optimisation perf mobile + accessibilite AA complete

## 15) Exemples de textes d'interface
Disclaimer global:
- Outil d'aide a la recherche, pas un conseil financier.

Confiance:
- Confiance elevee: donnees recentes et couverture complete.
- Confiance moyenne: certaines donnees manquent ou sont datees.
- Confiance faible: analyse indicative, verifier via sources primaires.

Pourquoi investir:
- Le business montre une croissance stable et une bonne conversion en cash, mais la valorisation exige une execution solide.

Pourquoi eviter:
- Sensibilite macro elevee et pression sur les marges dans un environnement de taux plus restrictif.

A surveiller:
- Publication resultats suivante, evolution de la marge brute, revision du consensus.

Empty state recherche:
- Aucun ticker trouve. Essaie le symbole exact (ex: AAPL) ou le nom de l'entreprise.

No data state:
- Donnees insuffisantes pour ce module. Consulte les sources detaillees ou reessaie plus tard.

## 16) Schema JSON de reponse d'analyse d'un ticker
Le schema JSON est fourni dans:
- docs/schemas/ticker_analysis_response.schema.json

## 17) Schema JSON de comparaison entre deux tickers
Le schema JSON est fourni dans:
- docs/schemas/ticker_comparison_response.schema.json

## Notes d'integration SIGMA actuelles
- Endpoints backend principaux utilises: quote, history, financials, analysis, news, events, insider, ownership, snapshot, search.
- Fallback Finnhub free prioritaire: market news, basic financials, recommendation trends, earnings surprises, earnings calendar, insider transactions, insider sentiment.
- Recommandation UX immediate: forcer l'ordre de lecture Resume -> KPIs -> Risques -> Scenarios pour limiter les mauvaises interpretations.
