import { LightningElement, api, track, wire } from "lwc";
// VD 01FEB24 - method renamed
import readQB from "@salesforce/apex/NxtController.processData";
//import NXTUTILS from '@salesforce/resourceUrl/NXTUTILS';
//import { loadScript } from 'lightning/platformResourceLoader';
// VD 09JAN24 - import nxtProcessQuestions method
import { nxtProcessQuestions } from "c/rCustomUtility";
import { CurrentPageReference } from "lightning/navigation";
// import getRequiredFields from "@salesforce/apex/FieldController.getRequiredFields";
// import getQuestion from "@salesforce/apex/QuestionController.getQuestion";
import queryRecords from "@salesforce/apex/RCustomLookupController.queryRecords";
import { stringInject } from "c/rCustomUtility";
import { QuestionMeta } from "c/metaModels";
import fetchAndStorePDF from "@salesforce/apex/PdfService.fetchAndStorePDF";
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


// MR - 22OCT23 - Created Preview Component for QB
export default class createPdf extends LightningElement {
  @api recordId;
  // @api qbId="a05fK000001n2zNQAQ"; // testing
  // @api qbId="a1WfK000000DSw9UAG"; // estimation
  @api pageId;
  @api languageCode;
  @api printMode;
  @api referenceMode;
  @api isQuesNo;
  @api isTitle;
  questionItem
  objectApiName
  filterQuery
  fieldsMetadata
  fldMetaMap
  fldQuestionsMap
  @track dataFlag = false;
  @track qbItem;
  @track questions;
  tableFieldList
  sqOptions = new Map();
  @wire(CurrentPageReference) pageRef;
  jsonData
  res;

    // MR 20NOV23 Print Mode Changes
    constructor() {
      super();
      if (!this.printMode) {
        this.printMode = false;
      }
      if (!this.referenceMode) {
        this.referenceMode = false;
      }
    }
  
    // AP 09DEC24 - key changes
    connectedCallback() {
      // VD jan25 page ref changes
      this.qbId = this.pageRef?.state.c__qbId || this.qbId;
      this.printMode = this.pageRef?.state.c__printMode || this.printMode;
  
      this.referenceMode =
        this.pageRef?.state.c__referenceMode || this.referenceMode;
      //console.log('test1'+ this.isQuesNo);
      //console.log('test2'+ this.isTitle);
      // console.log('inside qbPreview connectedCallback() with recordId ' + this.recordId + ' and ' + this.printMode);
      sessionStorage.setItem("_rnxtPrintMode", this.printMode); // MR 29NOV23 Print Mode Changes
      // this.processQB();
    }
  
    renderedCallback() {
      // VD 09JAN24 - used direct method instead of using static resource
      // if(!window._rnxtUtilsSetFlag) {
      //     loadScript(this, NXTUTILS)
      //         .then(() => {
      //             console.log('Loaded NXTUTILS ' + window._rnxtUtilsVersion);
      //         })
      //         .catch(error => console.log(error));
      // }
    }
  
    async processQB() {
      // MR 12NOV23 Changes to support Record Id and QB Id
      if (!this.qbId) {
        this.qbId = this.recordId;
      }
  
      // MR 28NOV23 Changes to support Record Id and Page Id
      if (!this.pageId) {
        this.pageId = this.recordId;
      }
  
      if (this.qbId) {
        if (this.qbId.length === 18) {
          let paramMap = { createAnswerBookFlag: false };
          paramMap["c__record_id"] = this.recordId;
          paramMap.c__qb_id = this.qbId;
          // VD -27-dec-24 param changes
          let para = {
            dataType: "QuestionBook",
            operation: "read",
            param1: this.qbId,
            paramJSON: JSON.stringify(paramMap),
            languageCode: ""
          };
          // VD 12Jun24 - translation changes
          await readQB({
            requestJSON: JSON.stringify(para)
          })
            .then((result) => {
              if (result) {
                this.jsonData = JSON.parse(result);
                // console.log("jsondata",JSON.stringify(this.jsonData));
                this.qbItem = this.jsonData.questionbook;
                // VD 09JAN24 -  nxtProcessQuestions method calling
           
                this.questions = nxtProcessQuestions(
                  this.jsonData.questionbook.subQuestions,
                  this.jsonData.sqOptions,
                  this.jsonData.qbQueryResult,
                  []
  
                );
                this.jsonData.questionbook.subQuestions.forEach((sq)=>{
                  if(sq.type === "Table") {
                    this.loadQuestion(sq)
                  }
                 })
                // console.log("question data",JSON.stringify(this.questions));
                this.jsonData.questionbook.subQuestions = [...this.questions];
                this.dataFlag = true;
                // console.log("main data",JSON.stringify(this.jsonData));       
                 }
            })
            .catch((er) => {
              console.log("err" + er);
            });
        }   this.cancelQB();
      }
    }
    cancelQB() {
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  
 
    loadQuestion(questionObj) {
      // console.log("inside customTable.loadQuestion()");
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
        // console.log(fld);
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
          // console.log("adding fld to tablefieldlist");
          // console.log(fld);
          this.tableFieldList.push(fldObj);
        }
      });
      // console.log("below the tablefieldlist");
      // console.log("this.tableFieldList ", this.tableFieldList);
  
      this.loadTable();
    }
  
    // Function to read the data from Org using the Table Metadata
    loadTable() {
      // console.log("Inside the CustomTable.loadTable ==> ", this.recordId);
      if (this.filterQuery) {
        if (!this.recordId) {
          this.recordId = "0013t00001aiwwtAAA";
        } // Testing
        const params = { recordId: this.recordId };
        // console.log(
        //   "inside the CustomTable.loadTable " +
        //     this.filterQuery +
        //     " and " +
        //     this.recordId
        // );
        // console.log("before stringInject1" + this.filterQuery.slice());
        this.filterQuery = stringInject(this.filterQuery.slice(), params).slice();
        // console.log("after stringInject" + this.filterQuery);
      }
  
      if (this.fieldsMetadata) {
        this.loading = true;
        // console.log(
        //   "inside customTable loadTable " + JSON.stringify(this.fieldsMetadata)
        // );
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
            // console.log(
            //   "Inside the result on queryRecords ==> ",
            //   response.queryStr
            // );
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
                  // console.log("ques");
                  // console.log(ques);
                  fvItem.questions.push(ques);
  
                  fvList.push(fvItem);
                });
  
                // console.log(fvList);
  
                this.tableRecordList = [
                  ...this.tableRecordList,
                  { recordId: resElement.recordId, value: fvList }
                ];
              });
              // console.log("this.tableRecordList",JSON.stringify(this.tableRecordList));
              this.jsonData.questionbook.subQuestions.forEach((sq)=>{
                if(sq.type === "Table") {
                 sq.input=[...this.tableRecordList];
                }
               })
              // console.log("final data", JSON.stringify(this.jsonData));
              let send_data={
                "questionbook":this.jsonData.questionbook,
              }

              fetchAndStorePDF({ json: JSON.stringify(send_data), relatedRecordId: this.recordId })
                .then((result) => {   
                  console.log('result', result);
                   
                  console.log('before if');
                                  
                    if (result.success === true) {
                      
                      console.log('inside if');
                      
                        this.showToast('Success', 'PDF Created Successfully', 'success', 'sticky');
                        // alert('PDF Created Successfully');
                        
                    } else {
                        this.showToast('Error', result.message || 'Unknown error', 'error', 'dismissable');
                    }
                })
                .catch(error => {
                    this.showToast('Error', error.body ? error.body.message : 'Unknown error', 'error', 'dismissable');
                });


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

    showToast(title, message, variant, mode) {
      const toastEvent = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
        mode: mode
      });
      this.dispatchEvent(toastEvent);
    }
  }