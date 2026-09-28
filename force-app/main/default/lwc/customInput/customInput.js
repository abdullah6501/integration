import { LightningElement, api, wire, track } from "lwc";
// MR 23OCT23 Publish Subscribe Model Changes
// RT 27MAY25 - Added placeholder style changes
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import dependentChange from "@salesforce/messageChannel/DependentFieldChange__c";
//import question from '@salesforce/apex/QuestionMappingController.getQuestionType';

export default class CustomInput extends LightningElement {
  @wire(MessageContext) messageContext; // MR 23OCT23 Lightning Message Changes
  @api value; // Input value
  @api question; // Input question of type Question (make sure to define this type)
  @api disabled = false; // Input: is input disabled or not
  @api placeholder; // Input placeholder
  @api error; // Input error
  @api isOptional;

  @api ngClassValue; // Input ngClassValue
  @api idValue; // Input idValue
  @api focusEvent; // Input focusEvent

  @track inputValue; // Property to hold the input value
  @api printMode; // MR 20NOV23 Print Mode Changes
  dependencyObj; // MR 23OCT23 Lightning Message Changes
  subscription;

  // VD 24NOV23 - variable to ge the org data
  @api objectApiName; // Name of the Object from which Data will be retrieved
  @api filterQuery; // Condition for the records filteration
  @api fieldsMetadata; // input Field Metadata
  @api recordId;
  @api fromShengel;
  @api readOnly;
  @api placeholderStyle;
  @api stylekey;
  // VD 07DEC23 - variable for add dynamic style
  @track classList;
  @track styleList;
  inputElement;
  // Constructor
  constructor() {
    super();
    this.subscription = null;
  }

  get isRequired() {
    return this.isOptional == false && !this.value ? "required-input" : "";
  }

  // Lifecycle hook for component initialization
  connectedCallback() {
    // VD 30NOV23 - print mode change
    // VD 06MAR25 print mode changes
    // RT 29JUL25 - Print Style added
    if (!this.printMode) {
      const sessionPrintMode = sessionStorage.getItem("_rnxtPrintMode");
      this.printMode = sessionPrintMode === "true";
    }

    // Ensure value is always defined
    this.value = this.value || "";

    // ✅ Reset styles at the start to avoid carryover from previous loop iteration
    this.classList = null;
    this.styleList = null;

    if (this.question) {
      const question = JSON.parse(JSON.stringify(this.question));

      // MR 23OCT23 Publish Subscribe Model Changes
      if (this.question.inputDetail) {
        // this.dependencyObj = JSON.parse(this.question.inputDetail);
        this.dependencyObj = JSON.parse(JSON.stringify(this.question.inputDetail));
        this.subscribeToMessageChannel();
      }

      // MR 20NOV23 Flags from Question
      if (this.question.isOptional !== undefined) {
        this.isOptional = this.question.isOptional;
      }

      
  }
}

  // MR 23OCT23 Publish Subscribe Model Changes
  // Encapsulate logic for Lightning message service subscribe and unsubsubscribe
  subscribeToMessageChannel() {
    if (!this.subscription) {
      this.subscription = subscribe(
        this.messageContext,
        dependentChange,
        (change) => this.handleDependentFieldChange(change),
        { scope: APPLICATION_SCOPE }
      );
    }
  }



  unsubscribeToMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  // Handler for message received by component
  handleDependentFieldChange(change) {
    console.log('Dependency change received:', change);
    
    if (this.dependencyObj.sourceQuestionId == change.fromQuestionId) {
        // NEW: Check if we're in a table row context
        const isTableContext = this.question.tableRowId && change.sourceTableRowId;
        
        if (isTableContext) {
            // In table context, only process if same row
            if (this.question.tableRowId !== change.sourceTableRowId) {
                console.log('Skipping dependency - different table row');
                return;
            }
        }
        
        // Existing logic continues here...
        if (change.fromEventType == "select") {
            this.value = change.detail.arrItems[0].value.addlFldMap[this.dependencyObj.valueField];
        } else if (change.fromEventType == "dropdown-select") {
            if (change.ques?.inputDetail) {
                let dependentData = JSON.parse(change.ques.inputDetail);
                if (dependentData.dependentValue) {
                    this.value = dependentData.dependentValue[change.inputValue];
                }
            }
        } else if (
            change.fromEventType == "clnewbutton" ||
            change.fromEventType == "searchclear" ||
            change.fromEventType == "unselect" ||
            change.fromEventType == "searchnofound"
        ) {
            this.value = "";
        }
        
        let question = JSON.parse(JSON.stringify(this.question));
        this.dispatchInput(this.value, question);
    }
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  // Custom method to handle input changes
  handleInputChange(event) {
    this.inputValue = event.target.value;
    let question = JSON.parse(JSON.stringify(this.question));
    // Create and dispatch a custom event to notify the parent component
    this.dispatchInput(this.inputValue, question);
  }
  // VD VD 09jul25- Removed unecessary query and optimized in single query

  //  common method
  dispatchInput(value, question) {
    const eventPayload = {
      inputValue: value,
      ques: question
    };
    const inputChangeEvent = new CustomEvent("inputchange", {
      detail: eventPayload
    });
    this.dispatchEvent(inputChangeEvent);
  }
}