// MR 08NOV23 New Table Component for showing Data in columns & rows
import { LightningElement, api, track, wire } from "lwc";
import getQuestion from "@salesforce/apex/QuestionController.getQuestion";
import queryRecords from "@salesforce/apex/RCustomLookupController.queryRecords";
import { stringInject } from "c/rCustomUtility";
import { QuestionMeta, FieldValueWrapper } from "c/metaModels";
import { CurrentPageReference } from "lightning/navigation";
import NewValue from "@salesforce/schema/AccountHistory.NewValue";
import getRequiredFields from "@salesforce/apex/FieldController.getRequiredFields";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class CustomTable extends LightningElement {
  @api recordId; // default param available in LWC
  @api question;
  @api questionId; // Name of the Question which has the Table Metadata
  @api objectApiName; // Name of the Object from which Data will be retrieved
  @api filterQuery; // Condition for the records filteration
  @api fieldsMetadata; // Table Fields Metadata

  @api printMode = false; // printmode update

  // 13NOV13 - Dynamic Table with Fields as Elements on Table
  @api tableType; // Row or Block
  @track rowTypeTable;
  @track blockTypeTable;
  @track blockActions; // Action to be taken at the block level
  @track rowActions; // Action to be taken at the row level

  @track questionItem;
  @track hasActions;
  @track fldMetaMap;
  @track fldQuestionsMap; // MR 23NOV23 Table Handling

  isDialogDisplay = false; //based on this flag dialog box will be displayed with checkbox items
  isDisplayMessage = false; //to show 'No records found' message
  tableRecordList = [];
  tableFieldList = [];
  isAddRecord = false;
  @wire(CurrentPageReference) pageRef;
  requiredFields = [];
  metaFields = [];
  @track loading;

  connectedCallback() {
    if (!this.tableType) {
      this.rowTypeTable = true;
      this.blockTypeTable = false;
    }
    // VD 16NOV23 - if there is no recordId get it from pageRef
    if (!this.recordId) {
      this.recordId = this.pageRef?.attributes.recordId;
    }
    console.log("Inside the CustomTable.connectedCallback ==> ", this.recordId);

    if (this.question) {
      this.loadQuestion(this.question);
    } else if (this.questionId) {
      // Load the Table Metadata from the Question
      this.readQuestion(this.questionId);
    } else {
      console.error("No Question Data to Process!!!");
    }
  }

  // Function to read the Question (Table Metadata)
  readQuestion(qId) {
    getQuestion({
      quesId: qId
    })
      .then((respQuestion) => {
        console.log(
          "Inside the result on readQuestion ==> ",
          JSON.stringify(respQuestion)
        );
        this.loadQuestion(respQuestion);
      })
      .catch((error) => {
        console.log(JSON.stringify(error));
      });
  }

  // Function to load the data to questionItem and other related fields
  // VD jan25 wrapperchanges
  loadQuestion(questionObj) {
    console.log("inside customTable.loadQuestion()");
    this.questionItem = JSON.parse(JSON.stringify(questionObj));
    this.objectApiName = questionObj.title;
    this.filterQuery = questionObj.subTitle;
    // VD 24NOV23 - updated Fields_Meta__c field
    this.fieldsMetadata = JSON.parse(questionObj.fieldsMeta);
    // Complete fldMetaMap and tableFieldList
    this.fldMetaMap = {};
    this.fldQuestionsMap = {};
    this.tableFieldList = [];
    this.fieldsMetadata.forEach((fld) => {
      console.log(fld);
      // console.log(fld.name.replace(/\_[a-z]/g, x => x[1].toUpperCase()));
      // MR23NOV23 Storing of the Question in the Field Meta saves read operation which is reduntant.
      let fldQRef = JSON.parse(fld.questionReference);
      // MR 23NOV23 Type should be read from the Question Reference. Its usage on FieldMeta is redundant.
      let fldTyp = fldQRef.question.type ? fldQRef.question.type : fld.fldType;
      let fldMeta = JSON.parse(
        JSON.stringify(new QuestionMeta(fld.name, fldTyp, 1, 1))
      );
      let fldObj = JSON.parse(JSON.stringify(fld));
      fldObj.meta = fldMeta;
      this.fldMetaMap[fld.name] = fldMeta;
      this.fldQuestionsMap[fld.name] = fldQRef.question;
      if (fld.outputFlag == true) {
        console.log("adding fld to tablefieldlist");
        console.log(fld);
        this.tableFieldList.push(fldObj);
      }
    });
    console.log("below the tablefieldlist");
    console.log("this.tableFieldList ", this.tableFieldList);

    this.loadTable();
  }

  // Function to read the data from Org using the Table Metadata
  loadTable() {
    console.log("Inside the CustomTable.loadTable ==> ", this.recordId);
    if (this.filterQuery) {
      if (!this.recordId) {
        this.recordId = "0013t00001aiwwtAAA";
      } // Testing
      const params = { recordId: this.recordId };
      console.log(
        "inside the CustomTable.loadTable " +
          this.filterQuery +
          " and " +
          this.recordId
      );
      console.log("before stringInject1" + this.filterQuery.slice());
      this.filterQuery = stringInject(this.filterQuery.slice(), params).slice();
      console.log("after stringInject" + this.filterQuery);
    }

    if (this.fieldsMetadata) {
      this.loading = true;
      console.log(
        "inside customTable loadTable " + JSON.stringify(this.fieldsMetadata)
      );
      // Use QueryRecords to get the Table Data
      // VD 21DEC23 - param added for Query limit changes
      queryRecords({
        strInput: "",
        objectName: this.objectApiName,
        fieldsWrapper: JSON.stringify(this.fieldsMetadata),
        filterQuery: this.filterQuery,
        isSearchBox: false
      })
        .then((response) => {
          console.log(
            "Inside the result on queryRecords ==> ",
            response.queryStr
          );
          this.tableRecordList = [];

          if (response.records?.length > 0) {
            response.records.map((resElement) => {
              let fvList = [];

              resElement.filterFieldValueList.forEach((field) => {
                let fvItem = JSON.parse(JSON.stringify(field));
                fvItem.meta = this.fldMetaMap[field.fieldId];

                fvItem.questions = [];
                let ques = JSON.parse(
                  JSON.stringify(this.fldQuestionsMap[field.fieldId])
                );

                let style = {
                  showLabel: false
                };
                ques.input = fvItem.fieldValue;
                ques.style = JSON.stringify(style);
                ques.rowId =
                  "ques_" +
                  new Date().getTime() +
                  "_" +
                  Math.floor(Math.random() * 1000);
                console.log("ques");
                console.log(ques);
                fvItem.questions.push(ques);

                fvList.push(fvItem);
              });

              console.log(fvList);

              this.tableRecordList = [
                ...this.tableRecordList,
                { recordId: resElement.recordId, value: fvList }
              ];
            });
            console.log("this.tableRecordList");
            console.log(this.tableRecordList);
            this.loading = false;
            this.isDialogDisplay = true; //display dialog
            this.isDisplayMessage = false;
          } else {
            //display No records found message
            this.isDialogDisplay = false;
            this.isDisplayMessage = true;

            // Publish Subscribe Model Changes
            const evtCustomEvent = new CustomEvent("tabledatanotfound");
            this.dispatching(evtCustomEvent);
          }
        })
        .catch((error) => {
          this.error = error;
          this.items = undefined;
          this.loading = false;
          this.isDialogDisplay = false;
        });
    }
  }

  handleSelect(event) {
    console.log("inside customTable.handleSelect");
    const name = event.currentTarget.name;
    const value = event.currentTarget.value;
    const index = event.currentTarget.dataset.index;
    console.log("Name:" + name, "value: ", value + "index = " + index);
  }
  // VD 23jul24 - add,edit and delete funtionality

  handleChange(event) {
    let value = event.target.value;
    console.log(value);
  }

  // Function to read the data from Org using the Table Metadata
  addRecord(event) {
    this.getFields();

    //     console.log('inside customTable.addRecord for ' + event.currentTarget.value);
    //     // Create the record Instance
    //     let newRow = {};

    //     // Add the Table Record Fields
    //     newRow.labelName = '';
    //     newRow.recordId = 'newRow' + this.tableRecordList.length;
    //     newRow.recordName = '';

    //     // Add the filterFieldValueList - Table Fields
    //     console.log(this.tableFieldList);
    //     let fvList = [];
    //     this.tableFieldList.forEach(fld => {
    //         console.log('addRecord.fld ==> ', JSON.stringify(fld));
    //         let newfv = JSON.parse(JSON.stringify(fld));
    //         fld.fieldValue = '';
    //         fvList.push(fld);
    //     });

    //     console.log(fvList);

    //     newRow.value = JSON.parse(JSON.stringify(this.tableFieldList));
    //     console.log(newRow);

    //     this.tableRecordList = [...this.tableRecordList, newRow];
  }

  getFields() {
    this.loading = true;
    getRequiredFields({ objectApiName: this.objectApiName })
      .then((result) => {
        this.requiredFields = result.map((field) => ({
          name: field.name,
          label: field.label
        }));
        this.loading = false;
        console.log(this.requiredFields);
        // logic to add meta fields too
        //         // Get meta fields from fieldsMetadata
        //         this.metaFields = this.fieldsMetadata.map(field => ({
        //             name: field.apiName,
        //             label: field.label,
        //         }));
        //    // Merge metaFields into requiredFields and remove duplicates
        //     const allFields = [...this.requiredFields, ...this.metaFields];
        //     const uniqueFields = allFields.filter((field, index, self) =>
        //         index === self.findIndex((f) => f.name === field.name)
        //     );
        //     this.requiredFields = uniqueFields;
        if (this.requiredFields.length > 0) {
          this.isAddRecord = true;
        } else {
          this.isAddRecord = false;
          this.handleNewRecordSave();
        }
      })
      .catch((error) => {
        this.loading = false;
        console.error("Error fetching required fields: ", error);
        this.showToast("Error", error, "Error");
      });
  }

  handleNewRecordSave() {
    let newRow = {
      recordId: "newRow" + this.tableRecordList.length,
      value: []
    };
    let isFilledRequiredFields = true;
    this.tableFieldList.forEach((fld) => {
      let newfv = JSON.parse(JSON.stringify(fld));
      newfv.questions = [];
      let ques = JSON.parse(JSON.stringify(this.fldQuestionsMap[fld.name]));
      // ques.Id = 'ques_' + new Date().getTime() + '_' + Math.floor(Math.random() * 1000);
      ques.rowId =
        "ques_" + new Date().getTime() + "_" + Math.floor(Math.random() * 1000);
      ques.input = "";
      ques.style = JSON.stringify({ showLabel: false });
      newfv.fieldName = fld.name;
      newfv.fieldApiName = fld.apiName;
      newfv.fieldStyle = fld.widthStyle;
      newfv.questions.push(ques);
      newRow.value.push(newfv);
    });

    if (this.requiredFields.length > 0) {
      this.template
        .querySelectorAll("lightning-input-field")
        .forEach((inputField) => {
          const fieldApiName = inputField.fieldName;
          const fieldValue = inputField.value;
          newRow.value.forEach((fld) => {
            if (fld.apiName == "Id") {
              // if the field has standard name field it is read only
              fld.questions[0].isReadOnly = true;
            }
            fld.questions[0][fieldApiName] = fieldValue;
            // logic to for if meta field available in the modal
            if (fld.apiName == fieldApiName && fld.apiName != "Id") {
              fld.questions[0].input = fieldValue;
            }
          });
          if (
            fieldValue == null ||
            fieldValue == undefined ||
            fieldValue == ""
          ) {
            isFilledRequiredFields = false;
            this.showToast("Error", "fill the Required Fields!", "Error");
          }
        });
    } else {
      isFilledRequiredFields = true;
    }

    if (isFilledRequiredFields) {
      this.tableRecordList = [...this.tableRecordList, newRow];
      this.isAddRecord = false;
      const eventPayload = {
        inputValue: this.tableRecordList,
        ques: this.question
      };
      const tableData = new CustomEvent("tabledata", {
        detail: eventPayload
      });
      this.dispatchEvent(tableData);
    }
  }

  handleError(event) {
    console.error("Error saving record:", event.detail);
  }

  newInputChange(event) {
    console.log(event.target.value);
    let fieldApi = event.target.fieldName;
  }

  inputChange(event) {
    let updatedQues = JSON.parse(JSON.stringify(event.detail));
    console.log(updatedQues);
    console.log("before update: ", this.tableRecordList);
    this.tableRecordList.forEach((record) => {
      record.value.forEach((fld) => {
        let ques = fld.questions[0];
        if (ques.rowId == updatedQues.rowId) {
          ques.input = updatedQues.input;
        }
      });
    });
    console.log("after update: ", this.tableRecordList);
    const eventPayload = {
      inputValue: this.tableRecordList,
      ques: this.question
    };
    const data = new CustomEvent("tabledata", {
      detail: eventPayload
    });
    this.dispatchEvent(data);
  }

  closeModel() {
    this.isAddRecord = false;
  }

  delIconClicked(event) {
    console.log(
      "inside customTable.delIconClicked for " + event.currentTarget.dataset.id
    );
    const recordIdToDelete = event.currentTarget.dataset.id;
    this.tableRecordList = this.tableRecordList.filter(
      (record) => record.recordId !== recordIdToDelete
    );
    const eventPayload = {
      inputValue: this.tableRecordList,
      ques: this.question
    };
    const data = new CustomEvent("tabledata", {
      detail: eventPayload
    });
    this.dispatchEvent(data);
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}