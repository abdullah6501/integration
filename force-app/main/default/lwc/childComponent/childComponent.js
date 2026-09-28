import { LightningElement, api, track } from 'lwc';

export default class ChildComponent extends LightningElement {
    @api abc; // @api allows parent to send this value
    @track counter = 0; // @track makes this property reactive

    increaseCounter() {
        this.counter += 1; // This will automatically update the UI
    }
}