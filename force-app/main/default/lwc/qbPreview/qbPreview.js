import { LightningElement, api, track, wire } from "lwc";
// VD 01FEB24 - method renamed
import readQB from "@salesforce/apex/NxtController.processData";
//import NXTUTILS from '@salesforce/resourceUrl/NXTUTILS';
//import { loadScript } from 'lightning/platformResourceLoader';
// VD 09JAN24 - import nxtProcessQuestions method
import { nxtProcessQuestions } from "c/rCustomUtility";
import { CurrentPageReference } from "lightning/navigation";
import fetchAndStorePDF from "@salesforce/apex/PdfService.fetchAndStorePDF";

// MR - 22OCT23 - Created Preview Component for QB
export default class QbPreview extends LightningElement {
  @api recordId;
  @api qbId;
  @api pageId;
  @api languageCode;
  @api printMode;
  @api referenceMode;
  @api isQuesNo;
  @api isTitle;

  @track dataFlag = false;
  @track qbItem;
  @track questions;
  sqOptions = new Map();
  @wire(CurrentPageReference) pageRef;

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
    console.log("qb called");
    // VD jan25 page ref changes
    this.qbId = this.pageRef?.state.c__qbId || this.qbId;
    this.printMode = this.pageRef?.state.c__printMode || this.printMode;
    this.referenceMode =
      this.pageRef?.state.c__referenceMode || this.referenceMode;
    //console.log('test1'+ this.isQuesNo);
    //console.log('test2'+ this.isTitle);
    // console.log('inside qbPreview connectedCallback() with recordId ' + this.recordId + ' and ' + this.printMode);
    sessionStorage.setItem("_rnxtPrintMode", this.printMode); // MR 29NOV23 Print Mode Changes
    this.processQB();
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
              const jsonData = JSON.parse(result);
              this.qbItem = jsonData.questionbook;
              // VD 09JAN24 -  nxtProcessQuestions method calling
              this.questions = nxtProcessQuestions(
                jsonData.questionbook.subQuestions,
                jsonData.sqOptions,
                jsonData.qbQueryResult,
                []
              );
              this.dataFlag = true;
              console.log("main data",JSON.stringify(this.questions));
              fetchAndStorePDF(jsonData, this.pageId)

              this.dispatchEvent(new CustomEvent('jsonData', { detail: { pdf: this.jsonData } }));

            }
          })
          .catch((er) => {
            console.log("err" + er);
          });
      }
    }
  }

  handlePrintClick(event) {
    sessionStorage.setItem("_rnxtPrintMode", false);
    window.print();
  }
  /*
    processQuestions(qList, sqOps, qbQueryResult) {
        console.log('inside processQuestions');
        let questionList = [];

        // Works out the Options
        let sqOptions = new Map();
        for (const sq in sqOps) {
            sqOptions.set(sq, sqOps[sq]);
        }

        // Process the Question
        qList.forEach(sq => {
            if(sq.Type__c === 'Dropdown') {
                sq.Question_Options__r = sqOptions.get(sq.Id).Question_Options__r;
            } else if(sq.Type__c === 'Book') {
                if(sq.QB_Reference__c && sq.QB_Reference_Questions__c) {
                    let qData = JSON.parse(sq.QB_Reference_Questions__c);
                    sq.questions = window._rnxtProcessQuestions(qData.questionbook.Questions__r.records, qData.sqOptions, qbQueryResult);
                }
            }

            // questionList.push(this.getInputValue(JSON.parse(JSON.stringify(sq), qbQueryResult)));
            if(window._rnxtUtilsSetFlag) {
                questionList.push(window._rnxtGetInputValue(JSON.parse(JSON.stringify(sq), qbQueryResult)));
            } else {
                questionList.push(this.getInputValue(JSON.parse(JSON.stringify(sq), qbQueryResult)));
            }
        });

        return questionList;
    }

    getInputValue(qObj, queryResult) {
        const qType = qObj['Type__c'];
        const fmString = qObj['Fields_Meta__c'];
        const refField = qObj['Reference_Field__c'];

        console.log('inside getInputValue with ' + refField);
        let retValue = null;

        if(fmString) {
            let fmList = JSON.parse(fmString);
            if(queryResult) {
                if(qType === 'Dropdown') {
                    fmList.forEach(fld => {
                        if(queryResult[fld.apiName]) {
                            retValue = queryResult[fld.apiName];
                        }
                    });
                } else if(qType === 'List') {
                    retValue = {};
                    fmList.forEach(fld => {
                        if(fld.searchflag) {
                            if(fld.ischild) {
                                if(queryResult[fld.childobjname][fld.childobjfldname]) {
                                    retValue = queryResult[fld.childobjname][fld.childobjfldname];
                                }
                            } else if(queryResult[fld.apiName]) {
                                // console.log('value of ' + fld.apiName + ' is ' + queryResult[fld.apiName]);
                                retValue = queryResult[fld.apiName];
                            }
                        }
                    });
                } else if(qType === 'Date') {
                    if(refField == 'TODAY') {
                        retValue = new Date().toLocaleDateString();
                    }
                }
            }
        }

        console.log(retValue);
        qObj.input = retValue;
        return qObj;
    }
*/
}