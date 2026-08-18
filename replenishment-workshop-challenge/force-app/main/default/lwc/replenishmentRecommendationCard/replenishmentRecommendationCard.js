import { LightningElement, api } from 'lwc';

const EMPTY_RESULT = Object.freeze({
  title: 'Replenishment recommendation',
  summary: 'No recommendation details were returned.',
  storeName: '',
  riskLevel: '',
  orderId: '',
  estimatedTotal: null,
  recommendations: []
});

export default class ReplenishmentRecommendationCard extends LightningElement {
  result = EMPTY_RESULT;
  currentIndex = 0;

  @api
  get value() {
    return this.result;
  }

  set value(input) {
    this.result = this.normalize(input);
    this.currentIndex = 0;
  }

  get hasStoreName() {
    return Boolean(this.result.storeName);
  }

  get hasRiskLevel() {
    return Boolean(this.result.riskLevel);
  }

  get hasOrderId() {
    return Boolean(this.result.orderId);
  }

  get hasEstimatedTotal() {
    return Number.isFinite(this.result.estimatedTotal);
  }

  get hasRecommendations() {
    return this.result.recommendations.length > 0;
  }

  get riskClass() {
    const risk = this.result.riskLevel.toLowerCase();
    if (risk.includes('high') || risk.includes('critical')) {
      return 'risk risk_high';
    }
    if (risk.includes('medium') || risk.includes('moderate')) {
      return 'risk risk_medium';
    }
    return 'risk risk_low';
  }

  get previousDisabled() {
    return this.currentIndex <= 0;
  }

  get nextDisabled() {
    return (
      !this.result.recommendations.length ||
      this.currentIndex >= this.result.recommendations.length - 1
    );
  }

  get positionLabel() {
    const count = this.result.recommendations.length;
    return count ? `${this.currentIndex + 1} of ${count}` : 'No products';
  }

  get carouselDots() {
    return this.result.recommendations.map((recommendation, index) => ({
      index,
      title: `Show ${recommendation.name}`,
      cssClass: index === this.currentIndex ? 'dot dot_active' : 'dot'
    }));
  }

  showPrevious() {
    this.scrollToIndex(this.currentIndex - 1);
  }

  showNext() {
    this.scrollToIndex(this.currentIndex + 1);
  }

  handleDotClick(event) {
    this.scrollToIndex(Number(event.currentTarget.dataset.index));
  }

  handleScroll(event) {
    const track = event.currentTarget;
    const cards = Array.from(track.querySelectorAll('[data-carousel-item]'));
    if (!cards.length) {
      return;
    }
    const index = cards.reduce(
      (closest, card, cardIndex) => (
        Math.abs(card.offsetLeft - track.scrollLeft) <
        Math.abs(cards[closest].offsetLeft - track.scrollLeft)
          ? cardIndex
          : closest
      ),
      0
    );
    this.currentIndex = index;
  }

  scrollToIndex(requestedIndex) {
    const maximum = this.result.recommendations.length - 1;
    const index = Math.max(0, Math.min(maximum, requestedIndex));
    const track = this.template.querySelector('[data-id="track"]');
    const cards = track
      ? Array.from(track.querySelectorAll('[data-carousel-item]'))
      : [];
    if (!track || !cards[index]) {
      return;
    }
    this.currentIndex = index;
    track.scrollTo({ left: cards[index].offsetLeft, behavior: 'smooth' });
  }

  normalize(input) {
    let parsed = this.parse(input);
    if (Array.isArray(parsed)) {
      parsed = { recommendations: parsed };
    }
    if (!parsed || typeof parsed !== 'object') {
      return {
        ...EMPTY_RESULT,
        summary: parsed ? String(parsed) : EMPTY_RESULT.summary
      };
    }

    const source =
      parsed.replenishmentResult ||
      parsed.result ||
      parsed.data ||
      parsed.value ||
      parsed;
    if (source !== parsed && typeof source === 'string') {
      return this.normalize(source);
    }
    if (Array.isArray(source)) {
      return {
        ...EMPTY_RESULT,
        recommendations: source
          .filter(Boolean)
          .map((item, index) => this.normalizeItem(item, index))
      };
    }
    const objectSource = source && typeof source === 'object' ? source : parsed;
    const rawRecommendations =
      objectSource.recommendations ||
      objectSource.items ||
      objectSource.products ||
      objectSource.lineItems ||
      [];

    return {
      title: objectSource.title || objectSource.heading || EMPTY_RESULT.title,
      summary:
        objectSource.summary ||
        objectSource.message ||
        objectSource.rationale ||
        EMPTY_RESULT.summary,
      storeName: objectSource.storeName || objectSource.retailStoreName || '',
      riskLevel:
        objectSource.riskLevel ||
        objectSource.risk ||
        objectSource.priority ||
        '',
      orderId: objectSource.orderId || objectSource.replenishmentOrderId || '',
      estimatedTotal: this.toFiniteNumber(
        objectSource.estimatedTotal ??
          objectSource.totalAmount ??
          objectSource.orderTotal
      ),
      recommendations: (Array.isArray(rawRecommendations)
        ? rawRecommendations
        : [rawRecommendations]
      )
        .filter(Boolean)
        .map((item, index) => this.normalizeItem(item, index))
    };
  }

  normalizeItem(item, index) {
    const source =
      item && typeof item === 'object' ? item : { name: String(item) };
    return {
      key:
        source.productId ||
        source.id ||
        source.productCode ||
        `recommendation-${index}`,
      name:
        source.name || source.productName || source.title || 'Recommended item',
      productCode: source.productCode || source.sku || '',
      imageUrl: source.imageUrl || source.displayUrl || source.image || '',
      quantity: this.toFiniteNumber(
        source.quantity ?? source.recommendedQuantity ?? source.orderQuantity
      ),
      currentStock: this.toFiniteNumber(source.currentStock) ?? 0,
      safetyStock: this.toFiniteNumber(source.safetyStock) ?? 0,
      averageDailySales:
        this.toFiniteNumber(source.averageDailySales) ?? 0,
      leadTimeDays: this.toFiniteNumber(source.leadTimeDays) ?? 0,
      unitPrice: this.toFiniteNumber(source.unitPrice) ?? 0,
      estimatedLineValue:
        this.toFiniteNumber(source.estimatedLineValue) ?? 0,
      reason: source.reason || source.rationale || source.explanation || '',
      urgency: source.urgency || source.priority || '',
      urgencyClass: this.urgencyClass(source.urgency || source.priority || '')
    };
  }

  urgencyClass(value) {
    const urgency = value.toLowerCase();
    if (urgency.includes('critical')) {
      return 'urgency urgency_critical';
    }
    if (urgency.includes('high')) {
      return 'urgency urgency_high';
    }
    return 'urgency urgency_medium';
  }

  parse(input) {
    if (typeof input !== 'string') {
      return input;
    }
    try {
      return JSON.parse(input);
    } catch {
      return input;
    }
  }

  toFiniteNumber(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
  }
}