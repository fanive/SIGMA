class EducationalMetric {
  final String label;
  final String definition;
  final String calculation;
  final String interpretation;

  EducationalMetric({
    required this.label,
    required this.definition,
    required this.calculation,
    required this.interpretation,
  });
}

class EducationalContent {
  static EducationalMetric getMetricInfo(String label, String lang) {
    final isFr = lang == 'FR';
    final normalized = label.toUpperCase().trim();

    if (normalized.contains('P/E') || normalized.contains('C/B')) {
      return EducationalMetric(
        label: isFr
            ? 'Ratio Cours/Bénéfice (P/E)'
            : 'Price-to-Earnings Ratio (P/E)',
        definition: isFr
            ? 'Le ratio P/E mesure le prix actuel de l\'action par rapport à ses bénéfices par action.'
            : 'The P/E ratio measures the current share price relative to its per-share earnings.',
        calculation: isFr
            ? 'Prix de l\'action / Bénéfice par action (EPS).'
            : 'Stock Price / Earnings Per Share (EPS).',
        interpretation: isFr
            ? 'Un P/E élevé peut signifier que l\'action est surévaluée ou que les investisseurs attendent une forte croissance. Un P/E bas peut indiquer une sous-évaluation ou des problèmes fondamentaux.'
            : 'A high P/E could mean the stock is overvalued or investors expect high growth. A low P/E might indicate undervaluation or fundamental issues.',
      );
    }

    if (normalized.contains('FREE CASH') ||
        normalized.contains('FLUX DE TRÉSORERIE')) {
      return EducationalMetric(
        label: isFr
            ? 'Flux de Trésorerie Disponible (FCF)'
            : 'Free Cash Flow (FCF)',
        definition: isFr
            ? 'Le FCF représente l\'argent réel qu\'une entreprise génère après avoir payé ses dépenses d\'exploitation et ses investissements en capital.'
            : 'FCF represents the actual cash a company generates after paying for operating expenses and capital expenditures.',
        calculation: isFr
            ? 'Flux de trésorerie d\'exploitation - Dépenses en capital (CapEx).'
            : 'Operating Cash Flow - Capital Expenditures (CapEx).',
        interpretation: isFr
            ? 'C\'est l\'une des mesures les plus importantes. Un FCF positif permet de payer des dividendes, de racheter des actions ou de réduire la dette. S\'il est négatif, l\'entreprise brûle du cash.'
            : 'This is one of the most important metrics. Positive FCF allows for dividends, share buybacks, or debt reduction. If negative, the company is burning cash.',
      );
    }

    if (normalized.contains('MARKET CAP') ||
        normalized.contains('CAPITALISATION')) {
      return EducationalMetric(
        label: isFr ? 'Capitalisation Boursière' : 'Market Capitalization',
        definition: isFr
            ? 'La valeur totale de toutes les actions d\'une entreprise sur le marché.'
            : 'The total value of all of a company\'s shares in the market.',
        calculation: isFr
            ? 'Prix de l\'action x Nombre total d\'actions en circulation.'
            : 'Stock Price x Total Outstanding Shares.',
        interpretation: isFr
            ? 'Elle classe les entreprises : Large Cap (>10Mds\$), Mid Cap (2-10Mds\$), Small Cap (<2Mds\$). Elle indique la taille et la maturité de l\'entreprise.'
            : 'It classifies companies: Large Cap (>10B\$), Mid Cap (2-10B\$), Small Cap (<2B\$). It indicates the size and maturity of the company.',
      );
    }

    if (normalized.contains('ROE')) {
      return EducationalMetric(
        label: isFr
            ? 'Rendement des Capitaux Propres (ROE)'
            : 'Return on Equity (ROE)',
        definition: isFr
            ? 'Mesure la rentabilité d\'une entreprise par rapport à l\'argent investi par les actionnaires.'
            : 'Measures a company\'s profitability relative to the money invested by shareholders.',
        calculation: isFr
            ? 'Bénéfice net / Capitaux propres des actionnaires.'
            : 'Net Income / Shareholder Equity.',
        interpretation: isFr
            ? 'Un ROE élevé (ex: >15%) montre que l\'entreprise utilise efficacement l\'argent des investisseurs pour générer des profits.'
            : 'A high ROE (e.g., >15%) shows the company is effectively using investor money to generate profit.',
      );
    }

    if (normalized.contains('DEBT/EQUITY') ||
        normalized.contains('DETTE/CAPITAUX')) {
      return EducationalMetric(
        label: isFr ? 'Ratio Dette/Capitaux Propres' : 'Debt-to-Equity Ratio',
        definition: isFr
            ? 'Indique comment une entreprise finance ses opérations via la dette par rapport aux fonds propres.'
            : 'Indicates how a company finances its operations via debt versus equity.',
        calculation: isFr
            ? 'Total passif / Total capitaux propres.'
            : 'Total Liabilities / Total Shareholder Equity.',
        interpretation: isFr
            ? 'Un ratio > 1 signifie que l\'entreprise a plus de dettes que de fonds propres. Trop de dettes augmente le risque financier, surtout en période de hausse des taux.'
            : 'A ratio > 1 means the company has more debt than equity. Too much debt increases financial risk, especially when interest rates rise.',
      );
    }

    if (normalized.contains('MARGIN') || normalized.contains('MARGE')) {
      return EducationalMetric(
        label: isFr ? 'Marge Bénéficiaire' : 'Profit Margin',
        definition: isFr
            ? 'Le pourcentage de revenus qui se transforme en bénéfice net.'
            : 'The percentage of revenue that turns into net profit.',
        calculation: isFr
            ? '(Bénéfice net / Chiffre d\'affaires) x 100.'
            : '(Net Income / Revenue) x 100.',
        interpretation: isFr
            ? 'Indique l\'efficacité opérationnelle. Une marge élevée signifie que l\'entreprise contrôle bien ses coûts et possède souvent un avantage concurrentiel.'
            : 'Indicates operational efficiency. A high margin means the company controls costs well and often has a competitive advantage.',
      );
    }

    if (normalized.contains('DIVIDEND') || normalized.contains('RENDEMENT')) {
      return EducationalMetric(
        label: isFr ? 'Rendement du Dividende' : 'Dividend Yield',
        definition: isFr
            ? 'Le pourcentage du prix de l\'action versé chaque année sous forme de dividendes.'
            : 'The percentage of the stock price paid out each year as dividends.',
        calculation: isFr
            ? '(Dividende annuel par action / Prix de l\'action) x 100.'
            : '(Annual Dividend Per Share / Stock Price) x 100.',
        interpretation: isFr
            ? 'Un rendement élevé peut être attractif pour les revenus, mais s\'il est trop élevé (>10%), cela peut signaler que le dividende est à risque.'
            : 'A high yield can be attractive for income, but if too high (>10%), it might signal the dividend is at risk.',
      );
    }

    if (normalized.contains('BETA')) {
      return EducationalMetric(
        label: 'Beta',
        definition: isFr
            ? 'Mesure la volatilité d\'une action par rapport au marché global (généralement le S&P 500).'
            : 'Measures a stock\'s volatility relative to the overall market (usually the S&P 500).',
        calculation: isFr
            ? 'Calcul statistique de corrélation avec l\'indice de référence.'
            : 'Statistical calculation of correlation with the benchmark index.',
        interpretation: isFr
            ? 'Beta = 1 : évolue comme le marché. Beta > 1 : plus volatil (plus de risque/rendement). Beta < 1 : moins volatil (plus défensif).'
            : 'Beta = 1: moves with the market. Beta > 1: more volatile (higher risk/reward). Beta < 1: less volatile (more defensive).',
      );
    }

    if (normalized.contains('REVENUE') ||
        normalized.contains('CHIFFRE') ||
        normalized.contains('REVENUS')) {
      return EducationalMetric(
        label: isFr ? 'Chiffre d\'Affaires (Revenus)' : 'Revenue',
        definition: isFr
            ? 'Le montant total d\'argent généré par la vente de biens ou services.'
            : 'The total amount of money generated from the sale of goods or services.',
        calculation: isFr
            ? 'Prix x Quantité vendue.'
            : 'Price x Quantity Sold.',
        interpretation: isFr
            ? 'C\'est la "ligne du haut". La croissance des revenus est essentielle pour la pérennité à long terme de l\'entreprise.'
            : 'This is the "top line". Revenue growth is essential for the long-term sustainability of the company.',
      );
    }

    if (normalized.contains('EBITDA')) {
      return EducationalMetric(
        label: 'EBITDA',
        definition: isFr
            ? 'Bénéfice avant intérêts, impôts, dépréciation et amortissement. Mesure la performance opérationnelle brute.'
            : 'Earnings Before Interest, Taxes, Depreciation, and Amortization. Measures raw operational performance.',
        calculation: isFr
            ? 'Bénéfice net + Intérêts + Impôts + Dépréciation + Amortissement.'
            : 'Net Income + Interest + Taxes + Depreciation + Amortization.',
        interpretation: isFr
            ? 'Permet de comparer des entreprises avec des structures de capital et des régimes fiscaux différents.'
            : 'Allows comparison of companies with different capital structures and tax regimes.',
      );
    }

    // --- TECHNICAL INDICATORS ---

    if (normalized.contains('RSI')) {
      return EducationalMetric(
        label: 'RSI (Relative Strength Index)',
        definition: isFr
            ? 'Indicateur de momentum mesurant la vitesse et l\'ampleur des variations de prix.'
            : 'A momentum indicator that measures the speed and change of price movements.',
        calculation: '100 - [100 / (1 + RS)]',
        interpretation: isFr
            ? 'RSI > 70 : Surachat (signal de vente potentiel). RSI < 30 : Survente (signal d\'achat potentiel).'
            : 'RSI > 70: Overbought (potential sell). RSI < 30: Oversold (potential buy).',
      );
    }

    if (normalized.contains('MACD')) {
      return EducationalMetric(
        label: 'MACD (Moving Average Convergence Divergence)',
        definition: isFr
            ? 'Suit la relation entre deux moyennes mobiles pour détecter les changements de tendance.'
            : 'Follows the relationship between two moving averages to detect trend changes.',
        calculation: '12-period EMA - 26-period EMA',
        interpretation: isFr
            ? 'Croisement au-dessus de la ligne de signal : Bullish. Croisement en-dessous : Bearish.'
            : 'Cross above signal line: Bullish. Cross below: Bearish.',
      );
    }

    if (normalized.contains('MA') || normalized.contains('MOYENNE MOBILE') || normalized.contains('AVG')) {
      return EducationalMetric(
        label: 'Moving Averages (SMA/EMA)',
        definition: isFr
            ? 'Lisse les données de prix pour identifier la direction de la tendance.'
            : 'Smoothes out price data to create a single flowing line to identify trend direction.',
        calculation: 'Somme des prix / Nombre de périodes',
        interpretation: isFr
            ? 'Prix au-dessus de la MA : Tendance haussière. Prix en-dessous : Tendance baissière.'
            : 'Price above MA: Uptrend. Price below MA: Downtrend.',
      );
    }

    if (normalized.contains('BOLLINGER')) {
      return EducationalMetric(
        label: 'Bollinger Bands',
        definition: isFr
            ? 'Mesure la volatilité via des bandes entourant une moyenne mobile.'
            : 'Measures market volatility using bands above and below a moving average.',
        calculation: 'MA +/- (2 x Ecart-type)',
        interpretation: isFr
            ? 'Bandes serrées : Explosion de prix imminente. Touche la bande haute : Surachat.'
            : 'Tight bands: Incoming price breakout. Touching upper band: Overbought.',
      );
    }

    if (normalized.contains('VOLUME')) {
      return EducationalMetric(
        label: 'Volume',
        definition: isFr
            ? 'Le nombre total d\'actions échangées sur une période donnée.'
            : 'The total number of shares traded during a specific time period.',
        calculation: 'Somme des transactions',
        interpretation: isFr
            ? 'Un volume fort confirme une tendance ou une cassure de prix. Un volume faible indique une hésitation.'
            : 'High volume confirms a trend or price breakout. Low volume indicates hesitation.',
      );
    }

    // Default Fallback
    return EducationalMetric(
      label: label,
      definition: isFr
          ? 'Donnée financière pour l\'analyse de la performance.'
          : 'Financial data for performance analysis.',
      calculation: '—',
      interpretation: isFr
          ? 'Consultez cette métrique pour évaluer la santé financière de l\'entreprise.'
          : 'Check this metric to evaluate company financial health.',
    );
  }
}
