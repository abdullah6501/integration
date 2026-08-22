import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { stringInject } from "c/rCustomUtility";
// MR 05FEB24 Import message service features.
import {
  publish,
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import fieldChangeChannel from "@salesforce/messageChannel/DependentFieldChange__c";

// VD 02FEB24 - imprt nxtProcessQuestions
import { nxtProcessQuestions } from "c/rCustomUtility";
// VD 01FEB24 - method renamed
import readQB from "@salesforce/apex/NxtController.newProcess";
import { skipQuestion } from "c/rCustomUtility";

export default class QuestionBook extends LightningElement {
  @api recordId;
  @api qbItem;
  @api questionItem; // To handle 1 Question at a time
  // VD23May25 changed to set method
  // @api questions; // To handle multiple questions at a time
  @api pageId; // VD 16NOV23 - input to get the page Id
  @api questionText; //AP 09DEC24 - defind question text
  @api translatedQuestions; // VD 11Jun24 - translation changes
  // MR 20NOV23 Print Mode Changes
  // The Query Param c__print_mode
  @api printMode;
  @api tableFilterQuery; //VD 26Feb25 filter Query
  // MR 20NOV23 Reference Mode Changes
  // In case of Reference Mode, the recordId plays a key role on fetching the data
  // The Query Param c__record_id and c__reference_mode
  // The SubText__c holds the Fields Meta and SubTitle__c holds the Filter Query
  @api referenceMode;
  // MR 23NOV23 Show or Hide Label for Custom Table
  @api showLabel;
  @api showQuestionEdit;
  @api isQuesNo;
  @api isTitle;
  @api isSubtitle = false;
  @track formStyleClass;

  @track orginalQuestions;
  questionBookItem;
  text;

  @track bookItem;
  dataFlag = false;
  @track style; //VD 07DEC23 - variable for book style

  // VD 19DEC23 - variables for header and footer changes
  @track bookHead;
  @track bookFoot;
  @track headerSpaceStyle;
  @track footerSpaceStyle;

  @wire(CurrentPageReference) pageRef;

  // MR 05FEB24 Lightning Message Changes
  @wire(MessageContext) messageContext;
  dependencyObj;
  subscription;

  // MR 25JAN24
  @track showPrevious;
  @track showNext;

  //my  calendar changes
  @api isCalendarModalOpen = false;
  @track calendarModalTitle;
  @track calendarModalSize;
  @track calendarSaveButtonValue;
  @track referenceQuestions = [];
  @track qbRefrenceBook;
  @track modalCalendarModalFooter;

  // VD23May25 child to track updates
  @api
  set questions(val) {
    this.processQuestionBookData(val);
  }

  get questions() {
    return this.orginalQuestions;
  }

  // MR 20NOV23 Print Mode Changes
  // AP 09DEC24 - key changes

  constructor() {
    super();
    if (!this.printMode) {
      this.printMode = false;
    }
    if (!this.referenceMode) {
      this.referenceMode = false;
    }
    // MR 23NOV23 Show or Hide Label for Custom Table
    if (!this.showLabel) {
      // console.log("this.showLabel insdie");
      //this.showLabel = true;
      this.formStyleClass = "form-group content-box";
    }

    // MR 25JAN24 Buttons Handling
    // VD JAN30 - added property instance
    this.showPrevious = false;
    this.showNext = false;
  }
  // VD23May25 moved the data handling on common method
  connectedCallback() {
    this.processQuestionBookData(this.questions);
    console.log('Questionsss--->', JSON.stringify(this.orginalQuestions));
  }

  processQuestionBookData(questions) {
    this.recordId = this.pageRef?.attributes.recordId;
    // console.log(
    //   "inside QuestionBook connectedCallback() with recordId " +
    //     this.recordId +
    //     " and showLabel " +
    //     this.showLabel
    // );
    // MR 23NOV23 Condition to avoid exception since qbItem is not passed from Custom Table
    if (this.qbItem) {
      this.questionBookItem = JSON.parse(JSON.stringify(this.qbItem));
    } else {
      this.showLabel = false;
      this.formStyleClass = "";
    }

    // MR 05FEB24 - Questionnaire will pass only QuestionItem, Question Book will pass Questions
    if (this.questionItem) {
      this.orginalQuestions = JSON.parse(JSON.stringify([this.questionItem]));
      // VD 04jul25 - input handling changes
      if (this.questionItem.inputDetail) {
        this.questionItem.inputDetail = JSON.parse(
          this.questionItem.inputDetail
        );
        if (this.questionItem.inputDetail?.logics) {
          this.questionItem.inputDetail.logics = JSON.parse(
            this.questionItem.inputDetail.logics
          );
        }
        this.dependencyObj = this.questionItem.inputDetail;
      }
    } else {
      this.orginalQuestions = JSON.parse(JSON.stringify(questions));
    }

    // VD 30JAN23 - processOrginalQuestions method added to use commonly -->
    this.processOrginalQuestions(this.orginalQuestions);
    // VD 11Jun24 - translation changes
    this.processTranslatedQuestions();
  }

  renderedCallback() {
    // RT 29JUL25 - Remove existing print styles to avoid duplicates
    this.removePrintStyles();

    // RT 29JUL25 - Add new print styles based on current questions
    this.addDynamicPrintStyles();
  }

  decodeHTMLEntities(text) {
    const textarea = document.createElement("textarea");
    textarea.innerHTML = text;
    return textarea.value;
  }

  @api processOrginalQuestions(questions) {
    this.orginalQuestions = questions;
    this.orginalQuestions.forEach((element, index) => {
      element.inputText = false;
      element.inputDropdown = false;
      element.location = false;
      element.CustomCalendar = false;
      element.textArea = false;
      element.inputDate = false;
      element.inputDateTime = false;
      element.inputCheckbox = false;
      element.inputAttachment = false;
      element.multiPickList = false;
      element.customLookup = false;
      element.customTable = false; // MR 12NOV23 - Custom Table Fix
      element.email = false;
      element.number = false;
      // VD 17NOV23 -- variable for image and label
      element.image = false;
      element.label = false;
      element.radio = false; // VD 02FEB24 - radio flag
      // VD 24NOV23 - added flag for book type ques
      element.book = false;
      // MR 13NOV23 - Condition to check for Blank Questions Labels
      if (element.questionText) {
        element.questionText = this.decodeHTMLEntities(element.questionText);

        element.questionText = element.questionText.replace(/<[^>]*>/g, "");
      }
      // AP 09DEC24 - key change
      element.errorFlag = false;
      if (element.type == "Text") {
        element.inputText = true;
      } else if (element.type == "Dropdown") {
        element.inputDropdown = true;
      } else if (element.type == "Location") {
        element.location = true;
      } else if (element.type == "TextArea") {
        element.textArea = true;
      } else if (element.type == "DateTime") {
        element.inputDateTime = true;
      } else if (element.type == "Checkbox") {
        element.inputCheckbox = true;
      } else if (element.type == "File") {
        element.inputAttachment = true;
      } else if (element.type == "MultiPickList") {
        element.multiPickList = true;
      } else if (element.type == "List") {
        element.customLookup = true;
      } else if (element.type == "Number") {
        element.number = true;
      } else if (element.type == "Email") {
        element.email = true;
      } else if (element.type == "Date") {
        element.inputDate = true;
      } else if (element.type == "Table") {
        element.customTable = true;
      } else if (element.type == "Image") {
        element.image = true;
      } else if (element.type == "Label") {
        element.label = true;
      } else if (element.type == "Calendar") {
        element.CustomCalendar = true;
      } else if (element.type == "Radio") {
        element.radio = true;
      } else if (element.type == "Book" || element.type == "Table") {
        element.book = true;
        if (!element.questions) {
          element.questions = [];
          if (element.qbReference) {
            let jsonData;
            if (element.qbReferenceQuestions) {
              jsonData = JSON.parse(element.qbReferenceQuestions);
              // VD 02FEB24 - used utility method
              element.questions = nxtProcessQuestions(
                jsonData.questionbook.subQuestions,
                jsonData.sqOptions,
                jsonData.qbQueryResult,
                JSON.parse(element.fieldsMeta) // VD 02FEB24 - nxtProcessQuestions method needs obeject data
              );
              console.log('nxtProcesseddd--->', JSON.stringify(element.questions));
              this.dataFlag = true;
            } else {
              let paramMap = new Map();
              paramMap.set("createAnswerBookFlag", false);
              // VD 12Jun24 - translation changes
              readQB({
                dataType: "QuestionBook",
                operation: "read",
                param1: element.qbReference,
                paramJSON: JSON.stringify(paramMap),
                languageCode: ""
              })
                .then((result) => {
                  if (result) {
                    const jsonData = JSON.parse(result);
                    // VD 02FEB24 - used utility method
                    // VD 02FEB24 - nxtProcessQuestions method needs Fields_Meta__c as obeject data
                    element.questions = nxtProcessQuestions(
                      jsonData.questionbook.subQuestions,
                      jsonData.sqOptions,
                      jsonData.qbQueryResult,
                      JSON.parse(element.fieldsMeta)
                    );
                    console.log('nxtProcesseddd--->', JSON.stringify(element.questions));
                    this.dataFlag = true;
                  }
                })
                .catch(() => null);
            }
          }
        } else {
          console.log("calling else element.questions ");
          //  VD 07DEC23 - dynamic  style changes
          console.log("Got Questions from Parent");
          if (element.qbReference) {
            // MR 06FEB24 Added condition to handle QB without References
            let bookItem = JSON.parse(element?.qbReferenceQuestions);
            element.qbItem = bookItem?.questionbook;
          } else {
            element.qbItem = {
              Id: element.questionBookId,
              style: element.questionBookSubTitle?.style
            };
          }

          element.questions.forEach((sq) => {
            if (sq.style != null && sq.style != "") {
              // VD 23MAY25 style json handling
              try {
                sq.style =
                  typeof sq.style === "object"
                    ? sq.style
                    : sq?.style
                    ? JSON.parse(sq.style)
                    : "";
              } catch (e) {
                sq.style = ""; // fallback if JSON.parse fails
              }
            } else if (
              element?.qbItem?.style != null &&
              element?.qbItem?.style != ""
            ) {
              sq.style = JSON.parse(element?.qbItem?.style);
              this.style = sq.style?.bookStyle ? sq.style?.bookStyle : "";
            } else {
              sq.style = {
                labelClass: "",
                labelStyle: "",
                inputClass: "",
                inputStyle: "",
                inputAlign: "",
                bookStyle: "",
                showLabel: true
              };
              this.style = "";
            }
          });

          this.dataFlag = true;
        }
      }

      if (element.style && element.style.labelValueStyle) {
        element.printValueDataAttr = `data-print-value-style-${index}`;

        //RT 29JUL25 - Store the print style for CSS generation
        this.storePrintStyleForCSS(
          element.style.labelValueStyle,
          `value-${index}`
        );
      }

      if (element.style && element.style.labelStyle) {
        element.printLabelDataAttr = `data-print-label-style-${index}`;

        //RT 29JUL25 - Store the print style for CSS generation
        this.storePrintStyleForCSS(
          element.style.labelStyle,
          `container-${index}`
        );
      }

      this.generateDataAttrPrintCSS();

      // Question Style Handling
      element.styleClass = "";
      // MR 06FEB24 - Disable/Hide Questions based on the Dependency Text
      // // VD 04jul25 - input handling changes
      if (element.inputDetail) {
        element.inputDetail =
          typeof element?.inputDetail === "object"
            ? element.inputDetail
            : JSON.parse(element.inputDetail);
        if (element.inputDetail?.logics) {
          element.inputDetail.logics =
            typeof element?.inputDetail.logics === "object"
              ? element.inputDetail.logics
              : JSON.parse(element.inputDetail.logics);
        }
        const quesDependencyObj = element.inputDetail;
        if (quesDependencyObj.hidden) {
          element.styleClass = "q-hide ";
        }
      }

      // MR 14NOV23 & 23NOV23 Style Size Fix
      if (element.size) {
        element.styleClass =
          element.styleClass + "slds-size_" + element.size + "-of-12";
      } else {
        element.styleClass = element.styleClass + "slds-size_12-of-12";
      }
      //  VD 07DEC23 - dynamic  style changes
      // SA - updating the label towards input box left to right - 2Dec23
      // // VD jan25 handle style json
      if (element.style != null && element.style != "") {
        element.style =
          typeof element?.style === "object"
            ? element.style
            : element?.style
            ? JSON.parse(element.style)
            : "";
        // element.style = JSON.parse(element?.style);
        // VD 19DEC23 - header and footer changes
        element.styleClass =
          element.styleClass +
          " " +
          (element.style?.classHeadFoot || "") +
          " " +
          (element.style?.classHeadFoot ? "display" : "");
      } else if (
        this.questionBookItem?.style != null &&
        this.questionBookItem?.style != ""
      ) {
        element.style = this.questionBookItem?.style
          ? JSON.parse(this.questionBookItem?.style)
          : "";
        // element.style = JSON.parse(this.questionBookItem?.style);

        this.style = element.style.bookStyle ? element.style.bookStyle : "";

        this.bookHead = element.style?.isHead || false;
        this.bookFoot = element.style?.isFoot || false;
        this.headerSpaceStyle =
          element.style?.headerSpaceStyle || "height: calc(20mm + 34px)";
        this.footerSpaceStyle =
          element.style?.footerSpaceStyle || "height: calc(20mm + 34px)";
      } else {
        // VD 19DEC23 - header and footer changes
        element.style = {
          labelClass: "",
          labelStyle: "",
          labelValueStyle: "",
          inputClass: "",
          inputStyle: "",
          inputAlign: "",
          bookStyle: "",
          classHeadFoot: "",
          headerSpaceStyle: "",
          footerSpaceStyle: "",
          showLabel: true,
          isHead: false,
          isFoot: false
        };
        this.style = "";
      }

      // RT 24JUL25 - added for decimal support
      if (
        element.type === "Number" &&
        element.input != null &&
        !isNaN(element.input) &&
        (element.minimumFractionDigits || element.maximumFractionDigits)
      ) {
        // Handle minimum fraction digits
        let minFraction = 0; // Default to 0
        if (
          element.minimumFractionDigits != null &&
          element.minimumFractionDigits !== ""
        ) {
          const parsed = parseInt(element.minimumFractionDigits, 10);
          if (!isNaN(parsed) && parsed >= 0) {
            minFraction = parsed;
          }
        }

        // Handle maximum fraction digits
        let maxFraction = 2;
        if (
          element.maximumFractionDigits != null &&
          element.maximumFractionDigits !== ""
        ) {
          const parsed = parseInt(element.maximumFractionDigits, 10);
          if (!isNaN(parsed) && parsed >= 0) {
            maxFraction = parsed;
          }
        }

        // Ensure maxFraction is at least minFraction
        if (maxFraction < minFraction) {
          maxFraction = minFraction;
        }

        element.input = Number(element.input).toLocaleString("en-US", {
          minimumFractionDigits: minFraction,
          maximumFractionDigits: maxFraction
        });
      }

      // MR 25JAN24 Buttons Handling
      // VD JAN30 - added property instance
      if (element.questionNumber > 1 && element.back != null) {
        this.showPrevious = true;
      }
      if (element.next != null) {
        this.showNext = true;
      }
    });
  }

  // VD 02FEB24 - process the book type question's book event
  processBookTypeData(event) {
    let evtSQ = JSON.parse(JSON.stringify(event.detail));
    const eventData = new CustomEvent("selectedbooktype", {
      bubbles: true,
      composed: false,
      detail: evtSQ
    });
    this.dispatchEvent(eventData);
  }

  childEventCapture(event) {
    // Capture and process child event
    let data = JSON.parse(JSON.stringify(event.detail));
    const rowIndex = data.rowIndex; // RT 27MAY25 - row index for dependent field handling
    // MR 13NOV23 Custom Lookup Bug Fixing
    if (data.ques) {
      if (data.ques.type === "File") {
        //RT 12FEB25 - Updated for file upload
        data.ques.input = data.attachmentValue;
      } else if (data.ques.type === "List" && data.arrItems) {
        data.ques.input = data?.arrItems[0]?.value;
      } else if (data.ques.type === "Checkbox") {
        // VD 06MAR25 if form means we need to pass the true/false value
        if (data.isForm) {
          console.log("dataflagVal-->" + data.flagVal);
          data.ques.input = data.flagVal;
        } else {
          const inpArray = JSON.parse(data.inputValue);
          data.ques.input = inpArray.length > 0 ? inpArray : "";
        }
      } else {
        // VD NOV23 - event handle
        data.ques.input = data.inputValue ? data.inputValue : "";
      }
    }

    this.handleDependency(data, rowIndex); // MR 05FEB24 Handling Question Dependency

    const eventData = new CustomEvent("selecteddata", {
      bubbles: true,
      composed: false,
      detail: data.ques
    });
    this.dispatchEvent(eventData);
  }
  // VD 11Jun24 - translation changes
  // AP 09DEC24 - key changes
  processTranslatedQuestions() {
    if (this.translatedQuestions && this.translatedQuestions.length > 0) {
      this.orginalQuestions.forEach((orgQuestion) => {
        this.translatedQuestions.forEach((transQuestion) => {
          if (orgQuestion.uniqueIdentifier == transQuestion.identifier) {
            orgQuestion.questionText = transQuestion.label;
            orgQuestion.question = transQuestion.placeHolder;
          }
        });
      });
    }
  }

  // MR 05FEB24
  // AP 09DEC24 - key changes
  handleDependency(changeData, rowIndex) {
    // ✅ Target only the row that triggered the change
    let element = this.orginalQuestions[rowIndex];
    if (!element) return;

    if (element.inputDetail) {
        element.inputDetail =
            typeof element?.inputDetail === "object"
                ? element.inputDetail
                : JSON.parse(element.inputDetail);

        if (element.inputDetail?.logics) {
            element.inputDetail.logics =
                typeof element?.inputDetail.logics === "object"
                    ? element.inputDetail.logics
                    : JSON.parse(element.inputDetail.logics);
        }

        const qd = element.inputDetail;
        if (changeData.ques.id == qd.sourceQuestionId) {
            const qState = skipQuestion(qd, {
                typ: changeData.ques.type,
                ansValue: changeData
            });
            if (qd.hidden) {
                element.styleClass = qState
                    ? element.styleClass.replaceAll("q-hide ", "")
                    : "q-hide " + element.styleClass;
            }
        }
    }

    // Required field validation
    if (changeData.ques.id == element.id) {
        if (changeData.ques.isOptional && !changeData.ques.input) {
            element.errorFlag = true;
            element.style.labelStyle += "color: red;";
        } else if (element.errorFlag) {
            element.errorFlag = false;
            element.style.labelStyle = element.style.labelStyle.replace(
                "color: red;",
                ""
            );
        }
    }
  }

  // MR 05FEB24
  announceChange(name, data) {
    let evt = new CustomEvent(name);
    if (data) {
      evt.detail = data;
    }
    this.dispatchEvent(evt);

    const payload = {
      fromQuestionId: this.questionItem.id,
      fromEventType: name,
      fromTableRowId: this.questionItem.tableRowId, // ADD: Row context
      detail: evt.detail
    };

    publish(this.messageContext, fieldChangeChannel, payload);
  }

  // MR 05FEB24
  handleChange(change) {
    if (this.dependencyObj.sourceQuestionId == change.fromQuestionId) {
      if (change.fromEventType == "select") {
        this.value =
          change.detail.arrItems[0].value.addlFldMap[
            this.dependencyObj.valueField
          ];
      } else if (
        change.fromEventType == "clnewbutton" ||
        change.fromEventType == "searchclear" ||
        change.fromEventType == "unselect" ||
        change.fromEventType == "searchnofound"
      ) {
        this.value = "";
      }
    }
  }

  handleEditClick(event) {
    const keyToEdit = event.target.dataset.key;
    const eventData = new CustomEvent("editquestion", {
      detail: keyToEdit
    });
    this.dispatchEvent(eventData);
  }

  handleDeleteClick(event) {
    let keyToDelete = event.target.dataset.key;
    const eventData = new CustomEvent("deletequestion", {
      detail: keyToDelete
    });
    this.dispatchEvent(eventData);
  }

  // RT 29JUL25 - Method to store print styles for CSS generation
  addDynamicPrintStyles() {
    if (!this.orginalQuestions || this.orginalQuestions.length === 0) return;

    let printStyles = "@media print {\n";

    this.orginalQuestions.forEach((ques, index) => {
      // Handle labelValueStyle
      if (ques.style && ques.style.labelValueStyle) {
        // Create a unique class for each question
        const uniqueClass = `print-label-value-${ques.id || index}`;

        // Convert inline styles to print styles
        const printStyle = this.convertToPrintStyle(ques.style.labelValueStyle);

        printStyles += `  .${uniqueClass} {\n`;
        printStyles += `    ${printStyle}\n`;
        printStyles += `  }\n`;

        // Add the class to the question's labelValueClass
        if (!ques.style.labelValueClass) {
          ques.style.labelValueClass = "";
        }
        if (!ques.style.labelValueClass.includes(uniqueClass)) {
          ques.style.labelValueClass += ` ${uniqueClass}`;
        }
      }

      // Handle labelStyle
      if (ques.style && ques.style.labelStyle) {
        // Create a unique class for label container
        const uniqueLabelClass = `print-label-container-${ques.id || index}`;

        // Convert inline styles to print styles
        const printLabelStyle = this.convertToPrintStyle(ques.style.labelStyle);

        printStyles += `  .${uniqueLabelClass} {\n`;
        printStyles += `    ${printLabelStyle}\n`;
        printStyles += `  }\n`;

        // Add the class to the question's labelClass
        if (!ques.style.labelClass) {
          ques.style.labelClass = "";
        }
        if (!ques.style.labelClass.includes(uniqueLabelClass)) {
          ques.style.labelClass += ` ${uniqueLabelClass}`;
        }
      }
    });

    printStyles += "}";

    // Inject the styles into the document
    this.injectPrintStyles(printStyles);
  }

  convertToPrintStyle(inlineStyle) {
    if (!inlineStyle) return "";

    // Parse inline styles and convert for print
    let printStyle = inlineStyle;

    // Convert font sizes to points for better print rendering
    printStyle = printStyle.replace(/font-size:\s*(\d+)px/g, (match, size) => {
      const ptSize = Math.round(parseInt(size) * 0.75); // Convert px to pt
      return `font-size: ${ptSize}pt`;
    });

    // Add important declarations for print
    printStyle = printStyle.replace(/;/g, " !important;");

    // Add print-specific enhancements
    if (!printStyle.includes("page-break-inside")) {
      printStyle += " page-break-inside: avoid !important;";
    }

    return printStyle;
  }

  injectPrintStyles(styles) {
    // Create or update the print style element
    let styleElement = document.getElementById("dynamic-print-styles");

    if (!styleElement) {
      styleElement = document.createElement("style");
      styleElement.id = "dynamic-print-styles";
      document.head.appendChild(styleElement);
    }

    styleElement.textContent = styles;
  }

  removePrintStyles() {
    const existingStyle = document.getElementById("dynamic-print-styles");
    if (existingStyle) {
      existingStyle.remove();
    }
  }

  addDynamicPrintStylesWithCustomProps() {
    this.orginalQuestions.forEach((ques, index) => {
      // Handle labelValueStyle
      if (ques.style && ques.style.labelValueStyle) {
        // Parse the inline styles into CSS custom properties
        const customProps = this.parseStylesToCustomProps(
          ques.style.labelValueStyle,
          `value-${index}`
        );

        // Add custom properties to the element's style
        if (!ques.style.labelValueStyle.includes("--print-")) {
          ques.style.labelValueStyle += customProps;
        }
      }

      // Handle labelStyle
      if (ques.style && ques.style.labelStyle) {
        // Parse the inline styles into CSS custom properties
        const customProps = this.parseStylesToCustomProps(
          ques.style.labelStyle,
          `container-${index}`
        );

        // Add custom properties to the element's style
        if (!ques.style.labelStyle.includes("--print-")) {
          ques.style.labelStyle += customProps;
        }
      }
    });
  }

  parseStylesToCustomProps(styleString, index) {
    let customProps = "";

    // Extract individual style properties
    const styles = styleString.split(";").filter((s) => s.trim());

    styles.forEach((style) => {
      const [property, value] = style.split(":").map((s) => s.trim());
      if (property && value) {
        // Create custom property for print
        customProps += `; --print-${property}-${index}: ${value}`;
      }
    });

    return customProps;
  }

  get computedQuestions() {
    if (!this.orginalQuestions) return [];

    return this.orginalQuestions.map((ques, index) => {
      const computed = { ...ques };

      // Handle labelValueStyle
      if (computed.style && computed.style.labelValueStyle) {
        // Add print-specific style attribute
        computed.printLabelValueStyle = this.generatePrintStyle(
          computed.style.labelValueStyle
        );

        // Create combined style for both screen and print
        computed.combinedLabelValueStyle = `${computed.style.labelValueStyle}; ${computed.printLabelValueStyle}`;
      }

      // Handle labelStyle
      if (computed.style && computed.style.labelStyle) {
        // Add print-specific style attribute
        computed.printLabelStyle = this.generatePrintStyle(
          computed.style.labelStyle
        );

        // Create combined style for both screen and print
        computed.combinedLabelStyle = `${computed.style.labelStyle}; ${computed.printLabelStyle}`;
      }

      return computed;
    });
  }

  generatePrintStyle(originalStyle) {
    if (!originalStyle) return "";

    // Create print-specific version of the style
    let printStyle = originalStyle;

    // Apply print-friendly transformations
    printStyle = this.convertToPrintStyle(printStyle);

    return printStyle;
  }

  storePrintStyleForCSS(style, identifier) {
    if (!this.printStylesMap) {
      this.printStylesMap = new Map();
    }

    this.printStylesMap.set(identifier, this.convertToPrintStyle(style));
  }

  generateDataAttrPrintCSS() {
    if (!this.printStylesMap || this.printStylesMap.size === 0) return;

    let cssRules = "@media print {\n";

    this.printStylesMap.forEach((style, identifier) => {
      if (identifier.startsWith("value-")) {
        const index = identifier.replace("value-", "");
        cssRules += `  [data-print-value-style-${index}] {\n`;
        cssRules += `    ${style}\n`;
        cssRules += `  }\n`;
      } else if (identifier.startsWith("container-")) {
        const index = identifier.replace("container-", "");
        cssRules += `  [data-print-label-style-${index}] {\n`;
        cssRules += `    ${style}\n`;
        cssRules += `  }\n`;
      }
    });

    cssRules += "}";

    this.injectPrintStyles(cssRules);
  }
}