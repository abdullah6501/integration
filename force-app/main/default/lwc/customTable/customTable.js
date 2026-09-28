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
import checkSalesforceId from "@salesforce/apex/Utility.isSalesforceId";

export default class CustomTable extends LightningElement {
  @api recordId; // default param available in LWC
  @api question;
  @api questionId; // Name of the Question which has the Table Metadata
  @api objectApiName; // Name of the Object from which Data will be retrieved
  @api filterQuery; // Condition for the records filteration
  @api fieldsMetadata; // Table Fields Metadata
  @api printMode = false; // printmode update
  // VD 05MAR25 table action changes
  @api isAddRowAction = false;
  @api isDeleteRowAction = false;
  dragStartIndex = null; //VD 21May25 row draggable changes

  // 13NOV13 - Dynamic Table with Fields as Elements on Table
  @api tableType; // Row or Block
  @track rowTypeTable;
  @track blockTypeTable;
  @track blockActions; // Action to be taken at the block level
  @track rowActions; // Action to be taken at the row level
  // VD 19Mar25 table S.no style changes
  @api isSno = false;
  @api isRowDraggable = false; // //VD 21May25 row draggable control
  @track snoHeadStyle;
  @track snoDataStyle;
  printStyleElement = null; // RT 29JUL25 - Element to hold print styles
  printStylesApplied = false; // RT 29JUL25 - Flag to check if print styles are applied

  @track questionItem;
  @track hasActions;
  @track fldMetaMap;
  @track fldQuestionsMap; // MR 23NOV23 Table Handling

  isDialogDisplay = false; //based on this flag dialog box will be displayed with checkbox items
  isDisplayMessage = false; //to show 'No records found' message
  @track tableRecordList = [];
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
    // get the filter from page url
    if (!this.filterQuery) {
      this.filterQuery = this.pageRef?.state.filterQuery || "";
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
    if (!this.filterQuery) {
      this.filterQuery = questionObj.subTitle;
    }
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
    // 13Mar25 get the  S.no colum styling
    this.tableFieldList?.forEach((fld) => {
      if (fld.tableHeadStyle) {
        this.snoHeadStyle = fld.tableHeadStyle;
      }
      if (fld.tableDataStyle) {
        this.snoDataStyle = fld.tableDataStyle;
      }
    });

    // In loadQuestion method, when creating questions for each table row
   

    // Update dependency object to include row context
    // if (ques.inputDetail) {
    //   let inputDetail = JSON.parse(ques.inputDetail);
    //   if (inputDetail.sourceQuestionId) {
    //     inputDetail.sourceQuestionId = inputDetail.sourceQuestionId + "_" + tableRowId;
    //   }
    //   ques.inputDetail = JSON.stringify(inputDetail);
    // }

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

                console.log("styleeee--->", JSON.stringify(ques));

                // Parse existing style if it exists, otherwise create new style object
                let style = {};
                
                if (ques.style) {
                    try {
                        // Try to fix common JSON formatting issues before parsing
                        let styleString = ques.style;
                        
                        // Fix missing comma before "id" property (common issue)
                        styleString = styleString.replace(/"\s*\n\s*"id"/, '",\n  "id"');
                        
                        // Try to parse the corrected JSON
                        style = JSON.parse(styleString);
                        console.log("Successfully parsed style:", style);
                        
                    } catch (e) {
                        console.warn("Failed to parse existing style JSON, creating new style object:", e);
                        console.warn("Original style string:", ques.style);
                        
                        // If parsing fails, start with empty style object
                        style = {};
                    }
                }
                
                // Always set showLabel to false, preserve other properties
                style.showLabel = false;
                
                // Convert back to JSON string
                ques.style = JSON.stringify(style);
                
                ques.rowId =
                  "ques_" +
                  new Date().getTime() +
                  "_" +
                  Math.floor(Math.random() * 1000);

                if (ques.element == "Book") {
                  let qbRef = JSON.parse(ques.qbReferenceQuestions);
                  if (qbRef) {
                    let queryResult = { ...resElement.addlFldMap };
                    queryResult[field.fieldApiName] = field.fieldValue;
                    qbRef.qbQueryResult = [queryResult];
                    ques.qbReferenceQuestions = JSON.stringify(qbRef);
                  }
                } else {
                  ques.input = fvItem.fieldValue;
                }

                console.log("quessss" + JSON.stringify(ques));
                fvItem.questions.push(ques);
                fvList.push(fvItem);
            });

              console.log(fvList);
              const tableRowId = "row" + new Date().getTime() + "_" + Math.floor(Math.random() * 1000);
              // Assign tableRowId to each question[0] in the value list
              fvList?.forEach(val => {
                if (val.questions?.length > 0) {
                  val.questions[0].tableRowId = tableRowId;
                }
              });
              // VD 13May25 - delete logic changes
              this.tableRecordList = [
                ...this.tableRecordList,
                {
                  recordId: resElement.recordId,
                  value: fvList,
                  tableRowId,
                  isDeleted: false
                }
              ];
            });
            // VD23May25 handle table data
            this.handleTableData();
            console.log("this.tableRecordList", JSON.stringify(this.tableRecordList));
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
    // VD23May25 removed unused commented code
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
  // VD 19Mar25 table S.no  changes
  // VD 13May25 - delete logic changes

  // VD23May25 handling the serial number column on the table
  handleTableData({ forceUpdate = false } = {}) {
    let serial = 1; // Manual counter for non-deleted records

    this.tableRecordList = this.tableRecordList.map((record) => {
      if (!record.isDeleted) {
        record.serialNumber = serial++;

        if (Array.isArray(record.value)) {
          record.value = record.value.map((col) => {
            if (Array.isArray(col.questions)) {
              col.questions = col.questions.map((q) => {
                if (q.isSerialNo === true) {
                  let serialInput;
                  if (
                    forceUpdate ||
                    col.fieldValue === undefined ||
                    col.fieldValue === null ||
                    col.fieldValue === ""
                  ) {
                    serialInput = record.serialNumber;
                    col.fieldValue = serialInput;
                  } else {
                    serialInput = col.fieldValue;
                  }

                  return { ...q, input: String(serialInput) };
                }
                return q;
              });
            }
            return col;
          });
        }
      }
      // Return unchanged if deleted
      return record;
    });
    this.dispatchTableData(this.tableRecordList);
  }

  // VD 13May25 - delete logic changes
  handleNewRecordSave() {
    try {
      let newRow = {
        recordId: "newRow" + this.tableRecordList.length,
        isDeleted: false,
        tableRowId:  "row" + new Date().getTime() + "_" + Math.floor(Math.random() * 1000),
        value: []
      };
      let isFilledRequiredFields = true;
      this.tableFieldList.forEach((fld) => {
        let newfv = JSON.parse(JSON.stringify(fld));
        newfv.questions = [];
        let ques = JSON.parse(JSON.stringify(this.fldQuestionsMap[fld.name]));
        // ques.Id = 'ques_' + new Date().getTime() + '_' + Math.floor(Math.random() * 1000);
        ques.rowId =
          "ques_" +
          new Date().getTime() +
          "_" +
          Math.floor(Math.random() * 1000);
        ques.tableRowId = newRow.tableRowId;
        ques.input = "";
        ques.style = JSON.stringify({ showLabel: false });
        newfv.fieldName = fld.name;
        newfv.fieldApiName = fld.apiName;
        // VD 19Mar25 table head and data style changes
        newfv.tableHeadStyle = fld.tableHeadStyle;
        newfv.tableDataStyle = fld.tableDataStyle;
        newfv.fieldStyle = fld.widthStyle;
        if (fld.tableHeadStyle) {
          this.snoHeadStyle = fld.tableHeadStyle;
        }
        if (fld.tableDataStyle) {
          this.snoDataStyle = fld.tableDataStyle;
        }
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
        // VD23May25 handle table data
        this.handleTableData({ forceUpdate: true });
      }
    } catch (error) {
      console.error("Error in handleNewRecordSave:", error);
    }
  }

  handleError(event) {
    console.error("Error saving record:", event.detail);
  }

  newInputChange(event) {
    console.log(event.target.value);
    let fieldApi = event.target.fieldName;
  }

  // Add this method to handle row-specific dependencies
  inputChange(event) {
    let updatedQues = JSON.parse(JSON.stringify(event.detail));
    console.log('Table inputChange:', updatedQues);
    
    try {
        this.tableRecordList.forEach((record) => {
            record.value.forEach((fld) => {
                let ques = fld.questions[0];
                if (ques.rowId == updatedQues.rowId) {
                    ques.input = updatedQues.input;
                    
                    // ADD: Set table row context for dependency
                    updatedQues.sourceTableRowId = record.tableRowId;
                }
            });
        });
        
        console.log('Updated table data:', this.tableRecordList);
        this.dispatchTableData(this.tableRecordList);
        
    } catch(error) {
        console.error('Error in inputChange:', error);
    }
  }

  closeModel() {
    this.isAddRecord = false;
  }

  async delIconClicked(event) {
    console.log(
      "inside customTable.delIconClicked for " + event.currentTarget.dataset.id
    );
    const recordIdToDelete = event.currentTarget.dataset.id;
    // VD 13May25 - delete logic changes
    // VD 13May25 Salesforce ID validation
    const isSalesforceId = await checkSalesforceId({ extId: recordIdToDelete });
    if (isSalesforceId) {
      // For existing Salesforce records, mark them as deleted
      this.tableRecordList = this.tableRecordList.map((record) => {
        if (record.recordId === recordIdToDelete) {
          return { ...record, isDeleted: true };
        }
        return record;
      });
    } else {
      // For new/unsaved records, just remove from the list
      this.tableRecordList = this.tableRecordList.filter(
        (record) => record.recordId !== recordIdToDelete
      );
    }
    // moved to common method
    this.handleTableData({ forceUpdate: true });
  }

  // VD 21May25 row draggable changes
  get getRowClass() {
    return this.isRowDraggable ? "draggable-row" : "";
  }
  get isrowDrag() {
    return this.isRowDraggable ? "true" : "false";
  }

  handleDragStart(event) {
    if (!this.isRowDraggable) return;
    this.dragStartIndex = event.currentTarget.dataset.index;
  }

  handleDragOver(event) {
    if (!this.isRowDraggable) return;
    event.preventDefault(); // allow drop
  }

  handleDrop(event) {
    if (!this.isRowDraggable) return;
    const dragEndIndex = event.currentTarget.dataset.index;

    if (this.dragStartIndex === null || dragEndIndex === null) return;
    const tempList = [...this.tableRecordList];
    const movedItem = tempList.splice(this.dragStartIndex, 1)[0];
    tempList.splice(dragEndIndex, 0, movedItem);
    this.tableRecordList = tempList;
    this.dragStartIndex = null;
    this.handleTableData({ forceUpdate: true });
  }
  // VD23May25 common method to dispatch the table data
  dispatchTableData(tableData) {
    const eventPayload = {
      inputValue: tableData,
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

  // RT 25JUL25 Method to create and inject print-specific CSS
  createPrintStyles() {
    // Remove existing print styles if any
    if (this.printStyleElement) {
      document.head.removeChild(this.printStyleElement);
    }

    // Create new style element
    this.printStyleElement = document.createElement("style");
    this.printStyleElement.setAttribute("data-component", "custom-table-print");

    let printCSS = "@media print {\n";

    // Generate unique class names based on field metadata
    this.tableFieldList.forEach((field, index) => {
      const headClass = `print-head-${index}`;
      const dataClass = `print-data-${index}`;

      console.log(`Generating styles for field ${index}:`, field.name);
      console.log("Head style:", field.tableHeadStyle);
      console.log("Data style:", field.tableDataStyle);

      // Convert tableHeadStyle to print-optimized styles
      if (field.tableHeadStyle) {
        const optimizedHeadStyles = this.optimizeStylesForPrint(
          field.tableHeadStyle,
          "head"
        );
        // Use higher specificity
        printCSS += `  table .${headClass}, th.${headClass} { ${optimizedHeadStyles} }\n`;
        console.log(
          `Generated head styles for ${headClass}: ${optimizedHeadStyles}`
        );
      }

      // Convert tableDataStyle to print-optimized styles
      if (field.tableDataStyle) {
        const optimizedDataStyles = this.optimizeStylesForPrint(
          field.tableDataStyle,
          "data"
        );
        // Use higher specificity
        printCSS += `  table .${dataClass}, td.${dataClass} { ${optimizedDataStyles} }\n`;
      }
    });

    // Add S.No column print styles if present with higher specificity
    if (this.snoHeadStyle) {
      const optimizedSnoHeadStyles = this.optimizeStylesForPrint(
        this.snoHeadStyle,
        "head"
      );
      printCSS += `  table .print-sno-head, th.print-sno-head { ${optimizedSnoHeadStyles} }\n`;
    }

    if (this.snoDataStyle) {
      const optimizedSnoDataStyles = this.optimizeStylesForPrint(
        this.snoDataStyle,
        "data"
      );
      printCSS += `  table .print-sno-data, td.print-sno-data { ${optimizedSnoDataStyles} }\n`;
    }

    printCSS += "}\n";

    console.log("=== FINAL GENERATED CSS ===");
    console.log(printCSS);

    // Set the CSS content and append to head
    this.printStyleElement.textContent = printCSS;
    document.head.appendChild(this.printStyleElement);

    // Add the background color forcing styles
    this.forceBackgroundColors();

    this.printStylesApplied = true;
  }
  // Method to optimize styles for print
  optimizeStylesForPrint(styleString, type) {
    if (!styleString) return "";

    const styles = styleString.split(";").filter((s) => s.trim());
    const optimizedStyles = [];

    // Always add print color adjustment properties first
    optimizedStyles.push("-webkit-print-color-adjust: exact !important");
    optimizedStyles.push("print-color-adjust: exact !important");
    optimizedStyles.push("color-adjust: exact !important");

    styles.forEach((style) => {
      let [property, value] = style.split(":").map((s) => s.trim());
      if (property && value) {
        // Apply print-specific optimizations
        switch (property.toLowerCase()) {
          case "font-size":
            // Reduce font size for print
            const fontSize = this.reduceFontSizeForPrint(value);
            optimizedStyles.push(`${property}: ${fontSize} !important`);
            break;
          case "padding":
          case "margin":
            // Reduce padding/margin for print
            const spacing = this.reducePaddingForPrint(value);
            optimizedStyles.push(`${property}: ${spacing} !important`);
            break;
          case "background-color":
            // Handle background color specifically
            optimizedStyles.push(`background-color: ${value} !important`);
            optimizedStyles.push(`background: ${value} !important`);
            // Add shadow as fallback for background color
            if (value && value !== "transparent" && value !== "none") {
              optimizedStyles.push(
                `box-shadow: inset 0 0 0 1000px ${value} !important`
              );
            }
            break;
          case "background":
            // Handle background shorthand
            optimizedStyles.push(`background: ${value} !important`);
            optimizedStyles.push(`background-color: ${value} !important`);
            // Extract color from background shorthand if possible
            const colorMatch = value.match(
              /#[0-9a-f]{3,6}|rgb\([^)]+\)|rgba\([^)]+\)|[a-z]+/i
            );
            if (
              colorMatch &&
              colorMatch[0] !== "transparent" &&
              colorMatch[0] !== "none"
            ) {
              optimizedStyles.push(
                `box-shadow: inset 0 0 0 1000px ${colorMatch[0]} !important`
              );
            }
            break;
          case "border":
          case "border-top":
          case "border-bottom":
          case "border-left":
          case "border-right":
            // Ensure borders are visible in print
            optimizedStyles.push(
              `${property}: ${value || ""} !important`
            );
            break;
          case "color":
            // Ensure text color is preserved
            optimizedStyles.push(`${property}: ${value} !important`);
            break;
          default:
            // Keep other styles as-is but make them important
            optimizedStyles.push(`${property}: ${value} !important`);
        }
      }
    });

    // Add word wrapping for print
    optimizedStyles.push("word-wrap: break-word !important");
    optimizedStyles.push("word-break: break-word !important");

    return optimizedStyles.join("; ");
  }

  // Helper method to reduce font size for print
  reduceFontSizeForPrint(fontSize) {
    const match = fontSize.match(/(\d+(?:\.\d+)?)(px|em|rem|%)/);
    if (match) {
      const value = parseFloat(match[1]);
      const unit = match[2];

      // Reduce by 20% for print, with minimum values
      let newValue;
      switch (unit) {
        case "px":
          newValue = Math.max(8, Math.round(value * 0.8)); // Min 8px
          break;
        case "em":
        case "rem":
          newValue = Math.max(0.6, value * 0.8); // Min 0.6em/rem
          break;
        case "%":
          newValue = Math.max(70, value * 0.8); // Min 70%
          break;
        default:
          newValue = value * 0.8;
      }
      return `${newValue}${unit}`;
    }
    return fontSize; // Return original if can't parse
  }

  // Helper method to reduce padding for print
  reducePaddingForPrint(padding) {
    return padding.replace(/(\d+(?:\.\d+)?)px/g, (match, value) => {
      const newValue = Math.max(2, Math.round(parseFloat(value) * 0.5)); // Min 2px, reduce by 50%
      return `${newValue}px`;
    });
  }

  // Method to apply print classes to DOM elements
  // Updated method to apply print classes more accurately
  applyPrintClasses() {
    // Apply classes to table headers
    const headers = this.template.querySelectorAll("th");
    let fieldIndex = 0;

    headers.forEach((header, headerIndex) => {
      // Skip drag handle column
      if (header.classList.contains("slds-no-print")) {
        return;
      }

      // Handle S.No column
      if (header.textContent.trim() === "S.No") {
        header.classList.add("print-sno-head");
        console.log("Applied print-sno-head to:", header.textContent);
        return;
      }

      // Handle Actions column
      if (header.textContent.trim() === "Actions") {
        return; // Skip actions column
      }

      // Apply field-specific classes
      if (fieldIndex < this.tableFieldList.length) {
        const className = `print-head-${fieldIndex}`;
        header.classList.add(className);
        console.log(`Applied ${className} to:`, header.textContent);
        fieldIndex++;
      }
    });

    // Apply classes to table data cells
    const rows = this.template.querySelectorAll("tbody tr");
    rows.forEach((row, rowIndex) => {
      const cells = row.querySelectorAll("td");
      let cellFieldIndex = 0;

      cells.forEach((cell, cellIndex) => {
        // Skip drag handle column
        if (cell.classList.contains("slds-no-print")) {
          return;
        }

        // Handle S.No column
        if (this.isSno && cellFieldIndex === 0) {
          cell.classList.add("print-sno-data");
          cellFieldIndex++;
          return;
        }

        // Handle Actions column
        if (cell.querySelector('lightning-icon[icon-name="utility:delete"]')) {
          return; // Skip actions column
        }

        // Apply field-specific classes
        const actualFieldIndex = this.isSno
          ? cellFieldIndex - 1
          : cellFieldIndex;
        if (
          actualFieldIndex >= 0 &&
          actualFieldIndex < this.tableFieldList.length
        ) {
          const className = `print-data-${actualFieldIndex}`;
          cell.classList.add(className);
          cellFieldIndex++;
        }
      });
    });
  }

  // Call this method after the table is rendered
  renderedCallback() {
    if (this.tableFieldList.length > 0 && !this.printStylesApplied) {
      // Create print styles
      this.createPrintStyles();

      // Apply print classes after a small delay to ensure DOM is ready
      setTimeout(() => {
        this.applyPrintClasses();
      }, 100);
    }
  }

  // Clean up when component is destroyed
  disconnectedCallback() {
    if (
      this.printStyleElement &&
      document.head.contains(this.printStyleElement)
    ) {
      document.head.removeChild(this.printStyleElement);
    }
  }

  forceBackgroundColors() {
    const printCSS = `
      @media print {
        /* Force all background colors using multiple methods */
        .custom-table th[style*="background"],
        .custom-table td[style*="background"],
        .print-head-0, .print-head-1, .print-head-2, .print-head-3, .print-head-4, .print-head-5,
        .print-data-0, .print-data-1, .print-data-2, .print-data-3, .print-data-4, .print-data-5,
        .print-sno-head, .print-sno-data {
          -webkit-print-color-adjust: exact !important;
          print-color-adjust: exact !important;
          color-adjust: exact !important;
          background-clip: padding-box !important;
        }
        
        /* Webkit specific background color forcing */
        @media (-webkit-min-device-pixel-ratio: 0) {
          th, td {
            -webkit-print-color-adjust: exact !important;
          }
        }
      }
    `;

    const forceStyleElement = document.createElement("style");
    forceStyleElement.setAttribute("data-component", "custom-table-force-bg");
    forceStyleElement.textContent = printCSS;
    document.head.appendChild(forceStyleElement);
  }

  // Update styles when table data changes (call this when data updates)
  updatePrintStyles() {
    this.printStylesApplied = false;
    this.createPrintStyles();
    setTimeout(() => {
      this.applyPrintClasses();
    }, 100);
  }
}