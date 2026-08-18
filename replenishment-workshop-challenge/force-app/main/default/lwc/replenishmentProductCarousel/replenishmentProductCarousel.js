import { LightningElement, api } from 'lwc';

export default class ReplenishmentProductCarousel extends LightningElement {
  _products = [];
  currentIndex = 0;
  resetScroll = false;

  @api
  get products() {
    return this._products;
  }

  set products(value) {
    this._products = Array.isArray(value) ? value : [];
    this.currentIndex = 0;
    this.resetScroll = true;
  }

  renderedCallback() {
    if (!this.resetScroll) {
      return;
    }
    const track = this.template.querySelector('[data-id="track"]');
    if (track) {
      track.scrollLeft = 0;
    }
    this.resetScroll = false;
  }

  get hasProducts() {
    return this.products.length > 0;
  }

  get previousDisabled() {
    return this.currentIndex <= 0;
  }

  get nextDisabled() {
    return (
      !this.products.length || this.currentIndex >= this.products.length - 1
    );
  }

  get positionLabel() {
    if (!this.products.length) {
      return 'No products';
    }
    return `Product ${this.currentIndex + 1} of ${this.products.length}`;
  }

  scrollPrevious() {
    this.scrollByDirection(-1);
  }

  scrollNext() {
    this.scrollByDirection(1);
  }

  scrollByDirection(direction) {
    const track = this.template.querySelector('[data-id="track"]');
    const item = this.template.querySelector('.carousel-item');
    if (!track || !item) {
      return;
    }
    const distance = item.getBoundingClientRect().width + 16;
    track.scrollBy({ left: direction * distance, behavior: 'smooth' });
    this.currentIndex = Math.min(
      this.products.length - 1,
      Math.max(0, this.currentIndex + direction)
    );
  }

  handleScroll(event) {
    const track = event.currentTarget;
    const item = this.template.querySelector('.carousel-item');
    if (!item) {
      return;
    }
    const distance = item.getBoundingClientRect().width + 16;
    this.currentIndex = Math.min(
      this.products.length - 1,
      Math.max(0, Math.round(track.scrollLeft / distance))
    );
  }
}