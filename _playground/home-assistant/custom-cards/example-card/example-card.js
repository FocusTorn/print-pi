// Example Custom Card for Home Assistant
// This is a template that demonstrates how to create a custom card
// that can be activated/enabled in Home Assistant like HACS cards

class ExampleCard extends HTMLElement {
  constructor() {
    super();
    this._config = null;
    this._hass = null;
    this._card = null;
    this._content = null;
  }

  setConfig(config) {
    if (!config.entity) {
      throw new Error('Please define an entity');
    }
    this._config = config;
    
    // Re-render if card already exists
    if (this._card) {
      this._renderCard();
    }
  }

  set hass(hass) {
    this._hass = hass;
    
    if (!this._card) {
      this._renderCard();
    }

    this._updateCard();
  }

  _renderCard() {
    // Remove existing card if present
    if (this._card && this._card.parentNode) {
      this._card.parentNode.removeChild(this._card);
    }

    // Create card element
    this._card = document.createElement('ha-card');
    if (this._config && this._config.title) {
      this._card.header = this._config.title;
    }
    
    // Create content container
    this._content = document.createElement('div');
    this._content.style.padding = '16px';
    this._card.appendChild(this._content);
    
    // Append to this element
    if (this._card.parentNode !== this) {
      this.appendChild(this._card);
    }
  }

  _updateCard() {
    if (!this._config || !this._hass || !this._content) {
      return;
    }

    const entityId = this._config.entity;
    const stateObj = this._hass.states[entityId];
    const state = stateObj ? stateObj.state : 'unavailable';
    const friendlyName = stateObj 
      ? (stateObj.attributes.friendly_name || entityId)
      : entityId;

    // Update card header if title changed
    if (this._card && this._config.title && this._card.header !== this._config.title) {
      this._card.header = this._config.title;
    }

    // Render content
    this._content.innerHTML = `
      <div style="text-align: center;">
        <div style="font-size: 24px; font-weight: bold; margin-bottom: 8px; color: var(--primary-text-color);">
          ${this._escapeHtml(state)}
        </div>
        <div style="font-size: 14px; color: var(--secondary-text-color);">
          ${this._escapeHtml(friendlyName)}
        </div>
        ${stateObj && stateObj.attributes.unit_of_measurement ? `
          <div style="font-size: 12px; color: var(--secondary-text-color); margin-top: 4px;">
            ${this._escapeHtml(stateObj.attributes.unit_of_measurement)}
          </div>
        ` : ''}
      </div>
    `;
  }

  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  getCardSize() {
    return 1;
  }

  // Optional: Handle configuration changes via UI editor
  static getStubConfig() {
    return {
      entity: 'sensor.example',
      title: 'Example Card'
    };
  }
}

// Register the custom element
if (!customElements.get('example-card')) {
  customElements.define('example-card', ExampleCard);
}

// Register the card type with Home Assistant
window.customCards = window.customCards || [];
window.customCards.push({
  type: 'example-card',
  name: 'Example Card',
  description: 'A simple example custom card that displays entity state',
  preview: true,
  documentationURL: 'https://github.com/yourusername/example-card'
});

