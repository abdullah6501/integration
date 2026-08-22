import { LightningElement, api, track, wire } from "lwc";
import formBuilder from "@salesforce/apex/FBController.formBuilder";
import readBooklet from "@salesforce/apex/NxtController.processData";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import generat_form from "@salesforce/apex/auto_form_generator.generat_form";
import { fireEvent } from "c/pubsub";
import { StyleWrapper } from "c/metaModels";

export default class FormBuilder extends LightningElement {
  @api recordId;
  selectedFormElement;
  pages = [];
  addedPage;
  updatedvalue; // pass and update the forms value
  formVale = [];
  formData = [];
  sectionId;
  noFormData;
  jsonData;
  booklet;
  abItem;
  questionbook;
  sqOptions = new Map();
  bookQuestionsMap = new Map();
  qbMap = new Map();
  oMap = new Map();
  pageOrderMap = new Map();
  sectionMap = new Map();
  questions = [];
  loading = false;
  @track sectionKeys = [];
  @track pageOptions = [];
  @track objectOption = [];
  selectedPageId;
  FormTitle;
  pages = [];
  wiredPageReferenceResult;
  isnewPage = false; // RT 03APR25 - Added a flag to notify new page creation to handleFinalData
  @track isPreview;
  // MA 19MAR25 -added Variable to cache data
  @track pageStateMap = new Map();
  @track selectedObject;
  @track pageTitleMap = new Map();
  @track pageActionMap = new Map(); //Actions/23Apr25/Thangarasu-pageActionMap
  @api dependentIdList = [];
  @api dependentFieldLabel = []; // RT 13MAY25 - Added to store dependent field labels
  @api FieldLabelMap = new Map();
  //AT 10MAY25 to maintain ai chat conversation
  ischatvisible = false;
  chathistory =[];
  @track chatmessages=[];
  @track chatloading = false;

  get pageOptionsCount() {
    return this.pageOptions ? this.pageOptions.length : 0;
  }

  connectedCallback() {
    // RT 22MAR25 - Preview Changes
    this.template.addEventListener(
      "getpageid",
      this.handleGetPageId.bind(this)
    );
  }

  disconnectedCallback() {
    // Clean up event listener
    this.jsonData = {};
    this.template.removeEventListener(
      "getpageid",
      this.handleGetPageId.bind(this)
    );
  }

  @wire(CurrentPageReference)
  getStateParameters(currentPageReference) {
    // Store the result for refreshApex
    // clear final data
    //AT 10MAY25 to omit unusual rendering
    this.ischatvisible = false;
    this.chatmessages=[];
    this.chathistory =[];
    this.isPreview = false;
    this.formVale = [];
    this.wiredPageReferenceResult = currentPageReference;

    if (
      currentPageReference &&
      currentPageReference.state &&
      currentPageReference.state.c__recordId
    ) {
      const newRecordId = currentPageReference.state.c__recordId;
      // Only reload if recordId has changed
      if (this.recordId !== newRecordId) {
        this.recordId = newRecordId;
        // Process form with the new recordId
        this.processForm();
      }
    } else {
      this.noFormData = true;
    }
  }

  // RT 13MAY25 - Added dependent logic
  processForm() {
    if (!this.noFormData) {
      this.loading = true;
    }
    if (this.recordId) {
      //console.log(this.recordId);
      if (this.recordId.length === 18) {
        //console.log("test");
        let paramMap = { createAnswerBookFlag: false };
        paramMap["c__record_id"] = "";
        paramMap.c__qb_id = "";
        let para = {
          dataType: "Form",
          operation: "read",
          param1: this.recordId,
          paramJSON: JSON.stringify(paramMap),
          languageCode: ""
        };
        //console.log(para);
        readBooklet({
          requestJSON: JSON.stringify(para)
        })
          .then((result) => {
            this.jsonData = JSON.parse(result);
            Object.values(this.jsonData.qMap).forEach((item) => {
              try {
                item.subText = JSON.parse(item.subText);
                if (
                  item.type === "List" ||
                  item.type === "Dropdown" ||
                  item.type === "Radio"
                ) {
                  console.log("Enter List");
                  const label = item.questionText || "";
                  const id = item?.id || item?.Id || "";
                  this.dependentIdList.push({ label, value: id });
                  console.log(
                    "dependentIdList --->",
                    JSON.stringify(this.dependentIdList)
                  );
                  if (item.element === "List") {
                    // Create a unique key from item id or generate one
                    const itemKey = item?.id || item?.Id || item.key || "";
                    // Initialize dependentFieldLabelOptions if not exists
                    item.dependentFieldLabelOptions = [];
                    item.columns.forEach((column) => {
                      const columnLabel = column.label || "";
                      const columnId =
                        column?.id || column?.Id || column.key || "";
                      item.dependentFieldLabelOptions.push({
                        label: columnLabel,
                        value: columnId
                      });
                    });
                    // Store in FieldLabelMap
                    this.FieldLabelMap.set(
                      itemKey,
                      item.dependentFieldLabelOptions
                    );
                  } else if (
                    item.element === "Dropdown" ||
                    item.element === "Radio"
                  ) {
                    // Create a unique key from item id or generate one
                    const itemKey = item?.id || item?.Id || item.key || "";
                    // Initialize dependentFieldLabelOptions if not exists
                    item.dependentFieldLabelOptions = [];
                    const options = item.options || [];
                    options.forEach((option) => {
                      const optionLabel = option.value || "";
                      const optionId =
                        option?.id || option?.Id || option.key || "";
                      item.dependentFieldLabelOptions.push({
                        label: optionLabel,
                        value: optionId
                      });
                    });
                    // Store in FieldLabelMap
                    this.FieldLabelMap.set(
                      itemKey,
                      item.dependentFieldLabelOptions
                    );
                  }
                }

                if (
                  item.subText.logics !== undefined &&
                  item.subText.logics.length > 0
                ) {
                  item.isDependentLogic = true;
                  item.dependentOperator = item.subText.logics[0].operation;
                  item.dependentFieldValue = item.subText.logics[0].value;
                  item.dependentIsHidden = item.subText.hidden;
                }
              } catch (error) {
                console.warn("Could not parse subText for item:", item, error);
              }
            });
            console.log("jsond", JSON.stringify(this.jsonData));
            // MA 16MAR25 - making seperate function
            this.handleJsonData();
            //console.log("Logging Map:", JSON.stringify([...this.sectionMap]));
          })
          .catch((er) => {
            //console.log(JSON.stringify("err-->" + er));
          });
      }
    }
  }
  // function to handle when new page is added
  handleJsonData(addedPage) {
    this.FormTitle = this.jsonData.name;
    this.loading = false;
    this.selectedObject = this.jsonData.anchorObj;
    this.pages = [...this.jsonData.pages];
    this.objectOption = [...this.jsonData.objectOptions];
    console.log("this.obj", this.objectOption);
    // Initialize maps if they don't exist
    this.qbMap = new Map(Object.entries(this.jsonData.qbMap || {}));
    this.oMap = new Map(Object.entries(this.jsonData.oMap || {}));

    this.pages.forEach((page) => {
      if (
        page.questionBook &&
        page.questionBook.id &&
        page.questionBook.title &&
        page.questionBook.category === "Booklet" &&
        page.order !== undefined
      ) {
        this.pageTitleMap.set(page.questionBook.id, page.questionBook.title);
        this.pageOrderMap.set(page.questionBook.id, page.order);
        // Actions/23Apr25/Thangarasu-Add `key` to each action before setting it in the map
        // Actions2/19May25/Thangarasu-pass styles attributes value to action attributes
        const updatedActions = (page.actions || []).map((action) => {
          return {
            ...action,
            key: this.generateKey(),
            isPageAction: true,
            isDeleted: false,
            btnColSize: action.styles?.[0]?.btnColSize ?? 6,
            btnColStyleClass:
              action.styles?.[0]?.btnColStyleClass ?? "slds-size_6-of-12",
            variant:
              action.styles?.[0]?.variant ?? "slds-button slds-button_brand",
            btnWidth: action.styles?.[0]?.btnWidth ?? 12,
            btnStyleClass:
              action.styles?.[0]?.btnStyleClass ??
              "slds-button slds-button_brand slds-size_12-of-12",
            btnHeight: action.styles?.[0]?.btnHeight ?? 40,
            btnStyle:
              action.styles?.[0]?.btnStyle ?? "box-shadow:none;height:40px;",
            btnPosStyle: action.styles?.[0]?.btnPosStyle ?? "text-align:left;",
            styleId: action.styles?.[0]?.styleId ?? ""
          };
        });
        this.pageActionMap.set(page.questionBook.id, updatedActions);
      }
    });
    // console.log("Page Title Map:", JSON.stringify([...this.pageTitleMap]));
    console.log("Page Order Map", JSON.stringify([...this.pageOrderMap]));

    // Process question map if it exists
    // RT 03APR25 - Element sorting
    if (this.jsonData.qMap) {
      for (const questionId in this.jsonData.qMap) {
        const question = this.jsonData.qMap[questionId];
        const questionBookId = question.questionBookId;
        const questionNo = question.questionNumber;
        let quesstyle = question.styles || {};
        console.log("quesstyle", JSON.stringify(quesstyle));

        if (this.qbMap.has(questionBookId)) {
          let existingSubQuestions =
            this.qbMap.get(questionBookId).subQuestions || [];

          // Check if question already exists
          const questionExists = existingSubQuestions.some(
            (q) => q.id === question.id
          );

          if (!questionExists) {
            // Add the question to existing subQuestions
            existingSubQuestions.push(question);
            // Sort the subQuestions array by questionNumber
            existingSubQuestions.sort(
              (a, b) => (a.questionNumber || 0) - (b.questionNumber || 0)
            );
            this.qbMap.get(questionBookId).subQuestions = existingSubQuestions;
          }
        }
      }
    }

    if (this.pages.length > 0) {
      // Create page options while maintaining existing order
      this.pageOptions = this.pages
        .sort((a, b) => a.order - b.order)
        .map((page) => ({
          label: `Page ${page.order}`,
          value: page.questionBook.id
        }));

      // Initialize formVale if not already initialized
      if (!this.formVale || !Array.isArray(this.formVale)) {
        this.formVale = [];
      }

      // Initialize selected page if not adding a new page
      if (!addedPage) {
        this.selectedPageId = this.pageOptions[0].value;
      }

      // Process all pages to ensure all sections are loaded
      this.pages.forEach((page) => {
        // Pre-load all sections for each page
        this.preloadPageSections(page.questionBook.id);
      });

      // Load the current page for display
      this.loadPageSections(this.selectedPageId);
    }
  }

  preloadPageSections(pageId) {
    if (this.pages.length > 0) {
      let newSectionMap = new Map();
      let pageSections = [];

      this.pages.forEach((page) => {
        if (page.questionBook.id === pageId) {
          page.records?.forEach((section) => {
            if (this.qbMap && this.qbMap.has(section.id)) {
              let sec = this.qbMap.get(section.id);

              // Create a clean question object without subQuestions
              const cleanQuestion = {
                id: sec.id,
                uniqueIdentifier: `QB-${this.generateKey()}`,
                totalQuestions: sec.totalQuestions,
                title: sec.title,
                progressBar: sec.progressBar,
                parentBooklet: sec.parentBooklet,
                order: sec.order,
                name: sec.name,
                isShengel: sec.isShengel,
                firstQuestion: sec.firstQuestion,
                category: sec.category
                // Include any other properties you need, but exclude subQuestions
              };

              // Store the original question (with subQuestions) separately if needed
              const originalQuestion = this.qbMap.get(section.id);
              const subQuestions = originalQuestion.subQuestions || [];
              //Actions/23Apr25/Thangarasu-add missing fields in actions
              // Actions2/19May25/Thangarasu-pass styles attributes value to action attributes
              const secActions =
                section.actions?.length > 0
                  ? section.actions.map((action) => ({
                      ...action,
                      key: this.generateKey(),
                      isActionClick: true,
                      isDeleted: false,
                      btnColSize: action.styles?.[0]?.btnColSize ?? 6,
                      btnColStyleClass:
                        action.styles?.[0]?.btnColStyleClass ??
                        "slds-size_6-of-12",
                      variant:
                        action.styles?.[0]?.variant ??
                        "slds-button slds-button_brand",
                      btnWidth: action.styles?.[0]?.btnWidth ?? 12,
                      btnStyleClass:
                        action.styles?.[0]?.btnStyleClass ??
                        "slds-button slds-button_brand slds-size_12-of-12",
                      btnHeight: action.styles?.[0]?.btnHeight ?? 40,
                      btnStyle:
                        action.styles?.[0]?.btnStyle ??
                        "box-shadow:none;height:40px;",
                      btnPosStyle:
                        action.styles?.[0]?.btnPosStyle ?? "text-align:left;",
                      styleId: action.styles?.[0]?.styleId ?? ""
                    }))
                  : [];

              newSectionMap.set(section.id, cleanQuestion);

              // Create formatted section for page state
              const formattedSection = {
                id: section.id,
                order: section.order || 0,
                pageId: pageId,
                question: cleanQuestion, // Use the clean question without subQuestions
                subQuestions: this.formatSubQuestions(subQuestions, section.id), // Formatted subQuestions at section level
                selectedObject: this.selectedObject,
                objOptions: this.objectOption,
                actions: secActions //Actions/23Apr25/Thangarasu-add action
              };
              pageSections.push(formattedSection);
              // RT 03APR25 - Sort page sections by order
              pageSections.sort((a, b) => (a.order || 0) - (b.order || 0));
            }
          });
        }
      });

      // Rest of the method remains the same...
      if (pageSections.length > 0) {
        this.pageStateMap.set(pageId, pageSections);
        let pageIndex = this.formVale.findIndex((p) => p.pageId === pageId);
        if (pageIndex !== -1) {
          this.formVale[pageIndex] = {
            pageId: pageId,
            sections: pageSections,
            order:
              this.pages.find((p) => p.questionBook.id === pageId)?.order || 0,
            title: this.pageTitleMap.get(pageId) || "New Page",
            actions: this.pageActionMap.get(pageId) //Actions/23Apr25/Thangarasu-add actions
            // title: this.pageTitleMap.get(questionBook.id) || "New Page"
          };
        } else {
          this.formVale.push({
            pageId: pageId,
            sections: pageSections,
            order:
              this.pages.find((p) => p.questionBook.id === pageId)?.order ||
              this.formVale.length + 1,
            title: this.pageTitleMap.get(pageId) || "New Page",
            actions: this.pageActionMap.get(pageId) //Actions/23Apr25/Thangarasu-add actions
            // title:
            //   this.pages.find((p) => this.pageTitleMap.get(questionBook.id)) || "New Page"
          });
        }
      }
    }
  }

  //GV 10APR25 - Added field meta configuration for file
  // RT 22APR25 - Added file size for field meta config
  formatSubQuestions(subQuestions, sectionId) {
    const generateKey = () => Math.random().toString(36).substring(2, 11);

    return subQuestions.map((sq, index) => {
      const uniqueIdentifier = `QB-${sq.questionBookId}-Q-${generateKey()}`;
      const key = generateKey();

      // let SQstyle = sq.styles || {};
      // console.log("SQstyle--->", JSON.stringify(SQstyle));
      let SQstyle =
        Array.isArray(sq?.styles) && sq.styles.length > 0
          ? sq.styles[0]
          : typeof sq?.styles === "object" && sq.styles !== null
          ? sq.styles
          : new StyleWrapper();
      console.log("SQstyle --->", JSON.stringify(SQstyle));

      // Parse fieldsMeta
      let fieldsMeta = [];
      if (sq.fieldsMeta) {
        try {
          fieldsMeta =
            typeof sq.fieldsMeta === "string"
              ? JSON.parse(sq.fieldsMeta)
              : sq.fieldsMeta;
        } catch (e) {
          console.error("Error parsing fieldsMeta:", e);
        }
      }

      // Format options
      const formattedOptions = sq.options
        ? sq.options.map((opt) => ({
            uniqueIdentifier: `QN-${sq.id}-OP-${generateKey()}`,
            value: opt.value,
            key: generateKey(),
            Id: opt.id
          }))
        : [];

      // Handle referenceField
      let objectApiName = this.selectedObject;
      let fieldApiName = sq.fieldApiName || "";

      // RT 31MAY25 - SubTitle Splitter to handle table filter retrieve
      let subtitlefieldApiName = "";
      let subtitleOperator = "";
      let subtitleValue = "";
      if (sq.subTitle) {
        const operatorIndex = sq.subTitle.indexOf("=");
        if (operatorIndex !== -1) {
          subtitlefieldApiName = sq.subTitle.slice(0, operatorIndex).trim(); // before =
          subtitleOperator = "="; // operator
          subtitleValue = sq.subTitle.slice(operatorIndex + 1).trim(); // after = (including quotes)
        } else {
          subtitlefieldApiName = sq.subTitle.trim(); // full string if no =
          subtitleOperator = "";
          subtitleValue = "";
        }
      }
      if (sq.referenceField && typeof sq.referenceField === "string") {
        const parts = sq.referenceField.split(".");
        if (parts.length === 2) {
          objectApiName = parts[0];
          fieldApiName = parts[1];
        }
      }

      // Build base object
      let formattedSubQuestion = {
        key,
        Id: sq.id,
        sectionId : sectionId,
        element: sq.type || "Text",
        helpText: sq.helpText || "",
        placeholder: sq.question || "", // RT 27MAY25 - Use question as placeholder
        fieldNo: index + 1,
        label: sq.questionText || sq.title || "",
        value: null,
        referenceField: sq.referenceField,
        uniqueIdentifier,
        uploadedFiles: [],
        columns: [],
        subText: sq.subText || {},
        style: SQstyle,
        isDependent: sq.isDependent || false,
        objectApiName: sq.title !== "" ? sq.title : "", // VD 29may25 used existing object api name to avoid overriding
        size: sq.size || 12,
        readOnly: sq.isReadOnly || false,
        isHide: sq.isHidden || false,
        isOptional: sq.isOptional || true,
        isText: sq.type === "Text",
        isTextArea: sq.type === "TextArea",
        isDateTime: sq.type === "DateTime",
        isPickList: sq.type === "Dropdown",
        isDate: sq.type === "Date",
        isNumber: sq.type === "Number",
        isFile: sq.type === "File",
        isEmail: sq.type === "Email",
        isCheckbox: sq.type === "Checkbox",
        isSearch: sq.type === "List",
        bookType: sq.type === "Book",
        isImage: sq.type === "Image",
        isLabel: sq.type === "Label",
        isRadio: sq.type === "Radio",
        isTable: sq.type === "Table",
        imgSrc: "",
        fieldApiName: sq.fieldApiName !== "" ? sq.fieldApiName : fieldApiName,
        styleClass: `slds-size_${sq.size || 12}-of-12`,
        options: formattedOptions,
        outputFlag: false,
        resultantflag: false,
        orderbyflag: false,
        filterflag: false,
        searchflag: false,
        dependentFieldLabelOptions: [],
        isDependentLogic: sq.subText?.logics?.length > 0 || false,
        isSno: sq.isSno || false,
        dependentOperator: sq.subText?.logics[0].operation || "",
        dependentFieldValue: sq.subText?.logics[0].value || "",
        dependentIsHidden: sq.subText?.hidden || false,
        tableHeadStyle: "",
        tableDataStyle: "",
        tableCondition: subtitleOperator,
        tableValue: subtitleValue,
        fieldMetaId: fieldsMeta.length > 0 ? fieldsMeta[0].id || "" : "",
        fileCount: fieldsMeta.length > 0 ? fieldsMeta[0].count || 0 : 0,
        fileSize: fieldsMeta.length > 0 ? fieldsMeta[0].fileSize || 0 : 0,
        fileType: fieldsMeta.length > 0 ? fieldsMeta[0].fileType || "" : ""
      };

      // VD 11jun25 Image type adjustment
      if (sq.type === "Image") {
        formattedSubQuestion.referenceField = "";
        formattedSubQuestion.objectApiName = "";
        formattedSubQuestion.fieldApiName = "";
        formattedSubQuestion.imgSrc = sq.title || "";
      }
      // SPECIAL HANDLING FOR TABLE QUESTIONS
      // RT 16MAY25 - Retrieve logic for table Head style and table data style
      if (sq.type === "Table") {
        // Get the table's columns from qbReferenceQuestions if available
        if (sq.qbReferenceQuestions) {
          try {
            const qbRefData = JSON.parse(sq.qbReferenceQuestions);
            if (qbRefData.questionbook && qbRefData.questionbook.subQuestions) {
              formattedSubQuestion.columns =
                qbRefData.questionbook.subQuestions.map((col) => {
                  const colKey = generateKey();
                  // Extract fieldApiName from referenceField if available
                  let fieldApiName = col.fieldApiName || "";
                  let objectApiName = this.selectedObject;

                  if (col.referenceField) {
                    const refParts = col.referenceField.split(".");
                    if (refParts.length === 2) {
                      objectApiName = refParts[0];
                      fieldApiName = refParts[1];
                    }
                  }
                  // Find the latest field meta for this column
                  let latestFieldMeta = {};
                  if (fieldsMeta && fieldsMeta.length > 0) {
                    // Filter meta for this column (assuming we can match by label or type)
                    const columnMetas = fieldsMeta.filter(
                      (meta) =>
                        meta.label === col.questionText ||
                        meta.fldType === col.type
                    );

                    // Get the latest one (assuming higher ID means newer)
                    if (columnMetas.length > 0) {
                      latestFieldMeta = columnMetas.reduce((latest, current) =>
                        current.id > latest.id ? current : latest
                      );
                    }
                  }
                  return {
                    key: colKey,
                    id: col.id,
                    element: col.type || "Text",
                    label: col.questionText || "",
                    fieldNo: col.questionNumber || 1,
                    isTableTypeList: true,
                    isEditable: !col.isReadOnly,
                    isDeletable: col.isDeleteRowAction,
                    showDelete: false,
                    referenceField: col.referenceField,
                    placeholder: col.question || "",
                    size: col.size || 12,
                    value: null,
                    options: [],
                    uploadedFiles: [],
                    subText: "",
                    styles: "",
                    isHide: col.isHidden || false,
                    readOnly: col.isReadOnly || false,
                    styleClass: `slds-size_${col.size || 12}-of-12`,
                    isOptional: col.isOptional || true,
                    outputFlag: latestFieldMeta.outputFlag || false,
                    orderbyflag: latestFieldMeta.orderbyflag || false,
                    filterflag: latestFieldMeta.filterflag || false,
                    searchflag: latestFieldMeta.searchflag || false,
                    resultantflag: latestFieldMeta.resultantflag || false,
                    objectApiName:
                      col.title !== "" ? col.title : this.selectedObject,
                    fieldApiName: fieldApiName || latestFieldMeta.apiName || "",
                    tableHeadStyle: latestFieldMeta.tableHeadStyle || "",
                    tableDataStyle: latestFieldMeta.tableDataStyle || "",
                    fieldMetaId: latestFieldMeta.id || "",
                    isdeleted: false
                  };
                });
            }
          } catch (e) {
            console.error("Error parsing qbReferenceQuestions:", e);
          }
        }

        // If no columns from qbReferenceQuestions, use fieldsMeta as fallback
        if (
          formattedSubQuestion.columns.length === 0 &&
          fieldsMeta.length > 0
        ) {
          formattedSubQuestion.columns = fieldsMeta.map((item, idx) => ({
            ...item,
            key: generateKey(),
            element: item.fldType || "Text",
            label: item.label || "",
            fieldNo: item.order || idx + 1,
            isTableTypeList: true,
            isEditable: true,
            isDeletable: true,
            showDelete: false,
            outputFlag: !!item.outputFlag,
            orderbyflag: !!item.orderbyflag,
            filterflag: !!item.filterflag,
            searchflag: !!item.searchflag,
            tableHeadStyle: item.tableHeadStyle || "",
            tableDataStyle: item.tableDataStyle || "",
            fieldApiName: item.apiName || "",
            fieldMetaId: item.id || ""
          }));
        }
      }
      // Handle List type similarly if needed
      else if (sq.type === "List") {
        formattedSubQuestion.columns = fieldsMeta.map((item, idx) => ({
          ...item,
          outputFlag: !!item.outputFlag,
          resultantflag: !!item.resultantflag,
          orderbyflag: !!item.orderbyflag,
          filterflag: !!item.filterflag,
          searchflag: !!item.searchflag,
          tableHeadStyle: item.tableHeadStyle || "",
          tableDataStyle: item.tableDataStyle || "",
          fieldApiName: item.apiName || "",
          fieldNo: item.order || idx + 1,
          isTableTypeList: true,
          fieldMetaId: item.id || "",
          referenceField: sq.title + "." + item.apiName,
          objectApiName: sq.title,
          isList: true,
          key: generateKey()
        }));
      }
      // For regular fields with metadata
      else if (fieldsMeta.length > 0) {
        const firstMeta = fieldsMeta[0];
        formattedSubQuestion = {
          ...formattedSubQuestion,
          outputFlag: !!firstMeta.outputFlag,
          resultantflag: !!firstMeta.resultantflag,
          orderbyflag: !!firstMeta.orderbyflag,
          filterflag: !!firstMeta.filterflag,
          searchflag: !!firstMeta.searchflag,
          fieldApiName: firstMeta.apiName || "",
          tableHeadStyle: firstMeta.tableHeadStyle || "",
          tableDataStyle: firstMeta.tableDataStyle || "",
          fieldMetaId: firstMeta.id || ""
        };
      }
      console.log("formattedSubQuestion", JSON.stringify(formattedSubQuestion));
      return formattedSubQuestion;
    });
  }

  // MA 16MAR25 - added PageChange
  // RT 11APR25 - Added pageTitlemap and refresh properties
  handlePageChange(event) {
    this.selectedPageId = event.detail;
    this.loadPageSections(this.selectedPageId, this.pageTitleMap);

    // Update properties panel with page title data when changing pages
    if (!this.isPreview) {
      const pageTitle = this.pageTitleMap.get(this.selectedPageId);
      const pageOrder = this.pageOrderMap.get(this.selectedPageId);

      this.handleInput({
        detail: {
          isPageTitle: true,
          data: pageTitle,
          pageOrder: pageOrder,
          pageId: this.selectedPageId
        }
      });
    }
    // if(this.isPreview === false) {
    //   this.template
    //     .querySelector("c-fb-properties")
    //     .refreshProperties(true);
    // }
  }
  // MA 19MAR25 - handle page with table
  loadPageSections(pageId, pageTitleMap = null) {
    if (this.pages.length > 0) {
      let newSectionMap = new Map();

      this.pages.forEach((page) => {
        if (page.questionBook.id == pageId) {
          page.records?.forEach((section) => {
            if (this.qbMap && this.qbMap.has(section.id)) {
              let sec = this.qbMap.get(section.id);
              if (sec.subQuestions?.length > 0) {
                sec.subQuestions = sec.subQuestions.map((sq) => {
                  sq.title = sq.title || this.anchorObject || "";
                  if (["Dropdown", "Checkbox", "Radio"].includes(sq.type)) {
                    let updatedSq = this.oMap?.get(sq.id);
                    return updatedSq || sq;
                  }
                  return sq;
                });
              }
              //Actions/23Apr25/Thangarasu-add missing fields in actions
              // Actions2/19May25/Thangarasu-pass styles attributes value to action attributes
              sec.actions =
                section.actions?.length > 0
                  ? section.actions.map((action) => ({
                      ...action,
                      key: this.generateKey(),
                      isActionClick: true,
                      isDeleted: false,
                      btnColSize: action.styles?.[0]?.btnColSize ?? 6,
                      btnColStyleClass:
                        action.styles?.[0]?.btnColStyleClass ??
                        "slds-size_6-of-12",
                      variant:
                        action.styles?.[0]?.variant ??
                        "slds-button slds-button_brand",
                      btnWidth: action.styles?.[0]?.btnWidth ?? 12,
                      btnStyleClass:
                        action.styles?.[0]?.btnStyleClass ??
                        "slds-button slds-button_brand slds-size_12-of-12",
                      btnHeight: action.styles?.[0]?.btnHeight ?? 40,
                      btnStyle:
                        action.styles?.[0]?.btnStyle ??
                        "box-shadow:none;height:40px;",
                      btnPosStyle:
                        action.styles?.[0]?.btnPosStyle ?? "text-align:left;",
                      styleId: action.styles?.[0]?.styleId ?? ""
                    }))
                  : [];
              newSectionMap.set(section.id, sec);
            } else {
              console.warn(
                `Skipping section ${section.id} because it does not exist in qbMap.`
              );
            }
          });
        }
      });

      this.sectionMap = newSectionMap;
      this.selectedPageId = pageId;
      this.pageTitleMap = pageTitleMap || this.pageTitleMap;

      if (this.pageStateMap.has(pageId)) {
        const savedState = this.pageStateMap.get(pageId);
        this.readQuestions(
          newSectionMap,
          pageId,
          savedState,
          this.pageTitleMap,
          this.pageOrderMap,
          this.pageActionMap //Actions/23Apr25/Thangarasu-add actionMap
        ); // RT 11APR25 - Added pageTitleMap
      } else {
        this.readQuestions(newSectionMap, pageId);
      }
    }
  }

  //Read the Questions
  // RT 11APR25 - Added pageTitleMap
  readQuestions(
    sectionMap,
    pageId,
    savedState = null,
    pageTitleMap = null,
    pageOrderMap = null
  ) {
    if (!sectionMap || !pageId) {
      console.warn("Required parameters missing in readQuestions:", {
        hasSectionMap: !!sectionMap,
        hasPageId: !!pageId
      });
      return;
    }

    try {
      // Dispatch form complete event first
      this.dispatchFormCompleteEvent();

      // Update pageTitleMap if provided
      if (pageTitleMap) {
        this.pageTitleMap = pageTitleMap;
      }
      // ASM 16APR25 - Update pageOrderMap
      if (pageOrderMap) {
        this.pageOrderMap = pageOrderMap;
      }

      // Get canvas component
      const canvasComponent = this.template.querySelector("c-fb-canvas");
      if (!canvasComponent) {
        throw new Error("Canvas component not found");
      }

      // Update form with safe parameters
      const formValue = canvasComponent.updateForm(
        sectionMap,
        pageId,
        savedState,
        this.selectedObject,
        this.pageTitleMap,
        this.pageOrderMap,
        this.pageActionMap //Actions/23Apr25/Thangarasu-add actionMap
      );

      // Refresh data
      if (sectionMap && typeof sectionMap === "object") {
        refreshApex(sectionMap);
      }
    } catch (error) {
      console.error("Error in readQuestions:", error);
      // Optionally dispatch error event or show toast
      this.showToast("Error", "Failed to load form data", "error");
    }
  }

  // RT 11APR25 - Page Title Input handling
  handleInput(event) {
    console.log(
      "handleInput selected",
      JSON.stringify(this.selectedFormElement)
    );
    let property = JSON.parse(JSON.stringify(event.detail));
    console.log("handleInput selected", JSON.stringify(property));

    property.anchorObject = this.selectedObject;
    if (!event.detail.isPageTitle) {
      if (property.isTableColumn && property.parentList?.objectApiName) {
        console.log(
          "Table column selected with parentList",
          JSON.stringify(property)
        );

        // For columns that already have their own objectApiName (different from parent)
        if (
          property.data.objectApiName &&
          property.data.objectApiName !== property.parentList.objectApiName
        ) {
          console.log(
            "Column has different objectApiName than parent - preserving column's objectApiName"
          );

          // Update referenceField using column's own objectApiName if fieldApiName exists
          if (property.data.fieldApiName) {
            property.data.referenceField = `${property.data.objectApiName}.${property.data.fieldApiName}`;
          }
        }
        // For columns without their own objectApiName or same as parent
        else {
          console.log("Using parentList's objectApiName for column");
          property.data.objectApiName = property.parentList.objectApiName;

          // Update referenceField if fieldApiName exists
          if (property.data.fieldApiName) {
            property.data.referenceField = `${property.parentList.objectApiName}.${property.data.fieldApiName}`;
          }
        }
      }
      // For List elements, use the objectApiName from columns if available
      else if (
        property.data.element === "List" &&
        property.data.columns?.length > 0
      ) {
        // Get the objectApiName from the first column that has it
        const columnWithObject = property.data.columns.find(
          (col) => col.objectApiName
        );
        if (columnWithObject?.objectApiName) {
          property.data.objectApiName = columnWithObject.objectApiName;

          // Ensure all columns have the same objectApiName
          property.data.columns.forEach((col) => {
            col.objectApiName = columnWithObject.objectApiName;
            // Update referenceField if fieldApiName exists
            if (col.fieldApiName) {
              col.referenceField = `${columnWithObject.objectApiName}.${col.fieldApiName}`;
            }
          });
        }
        // If no columns have objectApiName, fall back to selectedObject
        else if (this.selectedObject) {
          property.data.objectApiName = this.selectedObject;
        }
      } else if (
        property.data.element === "Table" &&
        property.data.columns?.length > 0
      ) {
        console.log(
          "Table element selected for property update:",
          JSON.stringify(property)
        );

        if (property.data.columns?.length > 0) {
          property.data.columns.forEach((col) => {
            // Only update referenceField if fieldApiName exists
            if (col.fieldApiName) {
              // Use column's own objectApiName if it exists, otherwise use parent's
              const effectiveObjectApiName =
                col.objectApiName ||
                property.data.objectApiName ||
                this.selectedObject;
              col.referenceField = `${effectiveObjectApiName}.${col.fieldApiName}`;

              // If column doesn't have objectApiName, set it from the effective one
              if (!col.objectApiName) {
                col.objectApiName = effectiveObjectApiName;
              }
            }
          });
        }
        console.log("Updated table property:", JSON.stringify(property));
      }
      // For non-list elements, use selectedObject
      else {
        // VD 29Mar25 assign object api name for local fields
        if (!property.data.Id) {
          property.data.objectApiName = this.selectedObject;
        }
        //
      }
      property.objOptions = Array.isArray(this.objectOption)
        ? [...this.objectOption]
        : this.objectOption;
      // Ensure property.obj is an array before pushing
      if (!Array.isArray(property.objectOptions)) {
        property.objOptions = [];
      }
      if (
        property.data.referenceField &&
        typeof property.data.referenceField === "string"
      ) {
        const parts = property.data.referenceField.split(".");
        if (parts.length === 2) {
          property.data.objectApiName = parts[0];
        }
      }
      // Push `this.obj` into `property.obj`
      property.objOptions.push(this.objectOption);
      console.log("inside form builder", JSON.stringify(property));
      this.selectedFormElement = property;
      console.log(
        "slectedFormElement",
        JSON.stringify(this.selectedFormElement)
      );
    } else if (event.detail.isPageTitle) {
      console.log("pagetitle in formbuilder", JSON.stringify(event.detail));
      console.log(
        "selectedformbefore assigning",
        JSON.stringify(this.selectedFormElement)
      );
      this.selectedFormElement = {
        pageTitle: event.detail.data,
        isPageTitle: event.detail.isPageTitle,
        pageOrder: event.detail.pageOrder || this.formVale.length - 1 + 1,
        pageId: this.selectedPageId // Add pageId to the payload
      };
      console.log(
        "else selectedform----",
        JSON.stringify(this.selectedFormElement)
      );
      // this.pageTitleMap.set(this.selectedPageId, event.detail.pageTitle);
      // this.selectedFormElement = event.detail;
    }
    // else if (event.detail.isPageTitle) {
    //   this.pageTitleMap.set(this.selectedPageId, event.detail.pageTitle);
    //   this.selectedFormElement = {
    //     pageTitle: event.detail.pageTitle,
    //     pageId: this.selectedPageId // Add pageId to the payload
    //   };
    // }

    if (property.isTableColumn) {
      //console.log("Column selected for property update:", property);
      this.template
        .querySelector("c-fb-properties")
        .selectedElement(this.selectedFormElement);
    } else {
      console.log(
        "Form element selected for property update:",
        JSON.stringify(this.selectedFormElement)
      );
      this.template.querySelector("c-fb-properties").selectedElement({
        ...this.selectedFormElement,
        anchorObject: this.selectedObject
      });
    }
  }

  // after updates from properties
  handleupdated(event) {
    this.updatedValue = JSON.parse(JSON.stringify(event.detail));
    this.selectedFormElement = this.updatedValue; // updated selected element with properties (used for to retain the previous selected values)
    // pass the updated value to forms
    const returnValue = this.template
      .querySelector("c-fb-canvas")
      .updateInput(this.updatedValue);
  }

  // ASM 16APR25 - Added page order change event
  handleOrderChange(event) {
    console.log("inside handle page order change");
    const { pageId, order } = event.detail;
    console.log("Page Order Change Event:", JSON.stringify(event.detail));
    console.log("page id in change", pageId);
    console.log("new order in change", order);

    if (!pageId || order === undefined || order < 1) {
      console.error("Invalid page order change parameters:", event.detail);
      return;
    }
    const updatedFormVale = JSON.parse(JSON.stringify(this.formVale));
    const pageIndex = updatedFormVale.findIndex(
      (page) => page.pageId === pageId
    );
    if (pageIndex === -1) {
      console.error("Page not found for reordering:", pageId);
      return;
    }
    const pageToMove = updatedFormVale[pageIndex];
    console.log("Page to move:", JSON.stringify(pageToMove));
    updatedFormVale.splice(pageIndex, 1);
    const insertPosition = Math.min(
      Math.max(0, order - 1),
      updatedFormVale.length
    );
    updatedFormVale.splice(insertPosition, 0, pageToMove);
    updatedFormVale.forEach((page, index) => {
      page.order = index + 1;
    });

    this.formVale = updatedFormVale;

    this.pageOptions = this.formVale
      .filter((page) => !page.isDeleted)
      .map((page) => ({
        label: `Page ${page.order}`,
        value: page.pageId
      }));
    this.pageOptions.sort((a, b) => a.order - b.order);

    // Keep the same page selected after reordering
    this.selectedPageId = pageId;

    if (this.jsonData && this.jsonData.pages) {
      this.jsonData.pages.forEach((page) => {
        const matchingPage = this.formVale.find(
          (p) => p.pageId === page.questionBook.id
        );
        if (matchingPage) {
          page.order = matchingPage.order;
        }
      });

      this.jsonData.pages.sort((a, b) => a.order - b.order);
    }

    // Update jsonData.pages order
    this.jsonData.pages.forEach((page) => {
      const matchingFormValue = this.formVale.find(
        (fv) => fv.pageId === page.questionBook.id
      );
      if (matchingFormValue) {
        page.order = matchingFormValue.order;
      }
    });
    this.jsonData.pages.sort((a, b) => a.order - b.order);

    // Update this.pages order to match jsonData.pages
    this.pages = [...this.jsonData.pages];

    // Rebuild pageOrderMap
    const newPageOrderMap = new Map();
    this.formVale.forEach((page) => {
      newPageOrderMap.set(page.pageId, page.order);
    });
    this.pageOrderMap = newPageOrderMap;

    // Update pageTitleMap to match new order
    const newPageTitleMap = new Map();
    this.formVale.forEach((page) => {
      const existingTitle = this.pageTitleMap.get(page.pageId);
      newPageTitleMap.set(page.pageId, existingTitle || `Page ${page.order}`);
    });
    this.pageTitleMap = newPageTitleMap;
    console.log("json data pages ", JSON.stringify(this.jsonData.pages));

    console.log("Pages reordered:", JSON.stringify(this.formVale));

    // Load the same page after reordering
    this.loadPageSections(pageId);

    // Fire input event to update properties
    this.handleInput({
      detail: {
        isPageTitle: true,
        data: this.pageTitleMap.get(pageId),
        pageOrder: this.pageOrderMap.get(pageId),
        pageId: pageId
      }
    });

    console.log("after page reordering:", JSON.stringify(this.formVale));
  }

  //SA- 12Dec23 - updated the delete functionality
  handleDeleteData(event) {
    // need to update as array push
    this.formVale = JSON.parse(JSON.stringify(event.detail));
    //console.log("testdelete", JSON.stringify(this.formVale));
    // this.handleFinalData(event);
  }
  //RT 27MAR25 - Delete Changes
  // Add new handler for element deletion
  handleElementDeleted() {
    // Reset the selected element in fbProperties
    const propertiesComponent = this.template.querySelector("c-fb-properties");
    if (propertiesComponent) {
      propertiesComponent.selectedElement({ data: null });
    }
  }

  handleFinalData(event) {
    let updatedItem = JSON.parse(JSON.stringify(event.detail));
    console.log("inside final data ", JSON.stringify(updatedItem));

    if (updatedItem.isPageTitle) {
      // Updatet the page title in pageTitleMap
      this.pageTitleMap.set(this.selectedPageId, updatedItem.pageTitle);

      // Find and update the corresponding page in formVale
      let pageIndex = this.formVale.findIndex(
        (p) => p.pageId === this.selectedPageId
      );
      if (pageIndex !== -1) {
        console.log("formVale---->>>>", JSON.stringify(this.formVale));
        // Ensure the object exists before assigning the title
        // if (!this.formVale[pageIndex]) {
        //   this.formVale[pageIndex] = {};
        // }
        // Only update title if it exists in the page object
        this.formVale[pageIndex].title = updatedItem.pageHeading
          ? updatedItem.pageHeading
          : "Untitled Page";
        this.pageTitleMap.set(this.selectedPageId, updatedItem.pageHeading);
      }
      console.log("formvaleupdateeee", JSON.stringify(this.formVale));
      // Exit early as we don't need to process sections for page title updates
    } else if (updatedItem.isPageAction) {
      //Actions/23Apr25/Thangarasu/ page actions handling
      this.pageActionMap.set(this.selectedPageId, updatedItem.data);

      let pageIndex = this.formVale.findIndex(
        (p) => p.pageId === this.selectedPageId
      );
      if (pageIndex !== -1) {
        this.formVale[pageIndex].actions = updatedItem.data
          ? updatedItem.data
          : this.formVale[pageIndex].actions;
      }
      console.log("formvaleupdateeee", JSON.stringify(this.formVale));
    } else if (updatedItem.data.length === 0 && updatedItem.status === true) {
      //RT 15APR2025 - Empty section handling
      this.formVale
        .filter((page) => page.pageId === updatedItem.pageId)
        .forEach((page) => {
          page.sections = [];
        });
      console.log(
        " Final Multi-Page Structure section deleted: ",
        JSON.stringify(this.formVale)
      );
    } else {
      // Get pageId from updated item or its first data element
      let pageId = updatedItem.pageId;
      let elementPageId = null;
      if (pageId === undefined) {
        elementPageId = updatedItem.data?.[0]?.pageId;
      }
      if (elementPageId != null) {
        pageId = elementPageId;
      }

      if (!pageId) {
        console.error("🚨 Error: pageId is missing!", updatedItem);
        return;
      }

      const sectionsData = updatedItem.data;
      this.dependentIdList = [];
      sectionsData.forEach((sd) => {
        Object.values(sd.subQuestions).forEach((item) => {
          try {
            if (
              item.element === "List" ||
              item.element === "Dropdown" ||
              item.element === "Radio"
            ) {
              console.log(
                "Processed List - objectApiName:",
                item.objectApiName
              );
              console.log("Enter List");
              const label = item.label || "";
              var optId = item?.Id ? item.Id : item.key;
              this.dependentIdList.push({ label, value: optId });
              console.log(
                "dependentIdList--->",
                JSON.stringify(this.dependentIdList)
              );
              item.dependentFieldLabelOptions = [];
              if (item.element === "List") {
                item.columns.forEach((col) => {
                  const label = col.label || "";
                  const id = col.Id ? col.Id : col.key;
                  item.dependentFieldLabelOptions.push({
                    label: label,
                    value: id
                  });
                });
                this.FieldLabelMap.set(optId, item.dependentFieldLabelOptions);
              } else if (
                item.element === "Dropdown" ||
                item.element === "Radio"
              ) {
                item.options.forEach((option) => {
                  const optionLabel = option.value || "";
                  const optionId = option.key;
                  item.dependentFieldLabelOptions.push({
                    label: optionLabel,
                    value: optionId
                  });
                  console.log("end-->");
                });
                this.FieldLabelMap.set(optId, item.dependentFieldLabelOptions);
              }
            }

            if (item.isDependentLogic) {
              let itemOperator = item.dependentOperator;
              item.subText.logics = [
                {
                  order: 1,
                  operation: itemOperator,
                  value: item.dependentFieldValue || ""
                }
              ];
              item.subText.hidden = true;
            }

            // if (item.subText && item.subText.sourceQuestionId) {
            //   const sourceElement = this.findElementByIdentifier(item.subText.sourceQuestionId);
            //   if (sourceElement.element === 'Dropdown' || sourceElement.element === 'Radio') {
            //     const options = Array.isArray(sourceElement.options) ? sourceElement.options : [];

            //     // Create logics only if options exist
            //     const updatedLogics = options.length > 0
            //       ? options.map((option, index) => ({
            //           order: index + 1,
            //           value: option.value || String(index + 1)
            //         }))
            //       : item.subText.logics || [];

            //     // Update the subText while preserving other properties
            //     item.subText = {
            //       ...item.subText,
            //       logics: updatedLogics
            //     };

            //     console.log('Successfully updated dependencies for:', item.Id || item.key);
            //   }
            // }
            if (item.element === "List") {
              const columnWithObject = item.columns?.find(
                (col) => col.objectApiName
              );
              if (columnWithObject?.objectApiName) {
                item.objectApiName = columnWithObject.objectApiName;
              }
              // Otherwise fall back to selectedObject
              else if (this.selectedObject) {
                item.objectApiName = this.selectedObject;
                // Also set it for all columns if they don't have it
                if (item.columns) {
                  item.columns.forEach((col) => {
                    if (!col.objectApiName) {
                      col.objectApiName = this.selectedObject;
                    }
                  });
                }
              }
              if (item.columns) {
                item.columns.forEach((col) => {
                  // Only set referenceField if both objectApiName and fieldApiName exist
                  if (col.objectApiName && col.fieldApiName) {
                    col.referenceField = `${col.objectApiName}.${col.fieldApiName}`;
                  }
                  // Clear referenceField if either is missing
                  else {
                    col.referenceField = null;
                  }
                });
              }
              //console.log("Processed List - objectApiName:", item.objectApiName);
              //item.objectApiName = this.selectedObject;
              // console.log("Enter List");
              // const label = item.label || '';
              // const id = item?.id || item?.Id || item.key || '';
              // const existingIndex = this.dependentIdList.findIndex(item => item.value === id);
              // if (existingIndex !== -1) {
              //   // ID exists, check if label is different
              //   if (this.dependentIdList[existingIndex].label !== label) {
              //     this.dependentIdList[existingIndex].label = label; // Update label
              //   }
              // } else {
              // ID does not exist, add new entry
              //this.dependentIdList.push({ label, value: id });
              // }
            } else if (item.element === "Table" && item.columns) {
              // Fix table column field numbers
              let fieldNo = 1;
              item.columns.forEach((col) => {
                if (!col.isdeleted) {
                  col.fieldNo = fieldNo++;
                }
              });
            }
          } catch (error) {
            console.warn("Could not parse subText for item:", item, error);
          }
        });
      });

      console.log("fieldlabelmap", JSON.stringify([...this.FieldLabelMap]));
      console.log("sectionsData", JSON.stringify(sectionsData));
      console.log("dependentIdList in handle", this.dependentIdList);

      this.pageStateMap.set(pageId, sectionsData);

      // Initialize formVale if needed
      if (!this.formVale || !Array.isArray(this.formVale)) {
        this.formVale = [];
      }

      const normalizedSectionsData = sectionsData
        .map((section, index) => ({
          ...section,
          order: section.order !== undefined ? section.order : index + 1
        }))
        .sort((a, b) => a.order - b.order);

      // Find the page with the given pageId
      let pageIndex = this.formVale.findIndex((pg) => pg.pageId === pageId);

      if (pageIndex !== -1) {
        // Page exists - update its sections
        const existingSections = this.formVale[pageIndex].sections || [];
        let sectionMap = new Map(
          existingSections.map((section) => [section.id, section])
        );

        // Update or add sections
        normalizedSectionsData.forEach((newSection) => {
          if (sectionMap.has(newSection.id)) {
            let existingSection = sectionMap.get(newSection.id);
            let subQuestionsMap = new Map(
              existingSection.subQuestions.map((sq) => [sq.key, sq])
            );

            newSection.subQuestions.forEach((newSubQ) => {
              if (newSubQ.isTable) {
                let existingTable = subQuestionsMap.get(newSubQ.key);
                if (existingTable) {
                  let columnMap = new Map(
                    existingTable.columns.map((col) => [col.key, col])
                  );

                  newSubQ.columns.forEach((col) => {
                    if (columnMap.has(col.key)) {
                      columnMap.set(col.key, {
                        ...columnMap.get(col.key),
                        ...col,
                        fieldApiName: col.fieldApiName,
                        objectApiName: col.objectApiName
                      });
                    } else {
                      columnMap.set(col.key, col);
                    }
                  });

                  existingTable.columns = Array.from(columnMap.values());
                } else {
                  subQuestionsMap.set(newSubQ.key, newSubQ);
                }
              } else {
                subQuestionsMap.set(newSubQ.key, newSubQ);
              }
            });

            existingSection.subQuestions = Array.from(
              subQuestionsMap.values()
            ).sort((a, b) => a.fieldNo - b.fieldNo);
            // Preserve the existing order unless explicitly changed
            sectionMap.set(newSection.id, {
              ...existingSection,
              ...newSection,
              order:
                newSection.order !== undefined
                  ? newSection.order
                  : existingSection.order
            });
          } else {
            sectionMap.set(newSection.id, newSection);
          }
        });

        this.formVale[pageIndex].sections = Array.from(
          sectionMap.values()
        ).sort((a, b) => (a.order || 0) - (b.order || 0));
      } else {
        // Add new page
        this.formVale.push({
          pageId: pageId,
          sections: normalizedSectionsData,
          order: this.formVale.length + 1
        });
      }

      // Ensure all pages exist in formVale
      if (this.pageOptions && this.pageOptions.length > 0) {
        const allPageIds = this.pageOptions.map((option) => option.value);
        const existingPageIds = this.formVale.map((page) => page.pageId);
        const missingPageIds = allPageIds.filter(
          (id) => !existingPageIds.includes(id)
        );

        // Add missing pages with their sections from qbMap
        missingPageIds.forEach((missingPageId) => {
          if (missingPageId !== pageId) {
            const pageSections = [];
            const relevantPage = this.pages.find(
              (p) => p.questionBook.id === missingPageId
            );

            if (relevantPage && relevantPage.records) {
              relevantPage.records.forEach((section) => {
                if (this.qbMap && this.qbMap.has(section.id)) {
                  const sec = this.qbMap.get(section.id);
                  // Create formatted section data
                  pageSections.push({
                    id: section.id,
                    order: section.order || 0,
                    pageId: missingPageId,
                    question: sec,
                    subQuestions: this.formatSubQuestions(
                      sec.subQuestions || [],
                      section.id
                    )
                  });
                }
              });
            }

            this.formVale.push({
              pageId: missingPageId,
              sections: pageSections,
              order: relevantPage
                ? relevantPage.order
                : this.formVale.length + 1
            });
          }
        });
      }

      // Handle event status if needed
      if (event.detail.status === true) {
        this.formVale = this.formVale.map((page) => {
          if (page.pageId === event.detail.data[0]?.pageId) {
            return {
              ...page,
              sections: [...updatedItem.data]
            };
          }
          return page;
        });
      } else {
        // Create page map and update formVale
        let pageMap = new Map(this.formVale.map((pg) => [pg.pageId, pg]));

        if (pageMap.has(pageId)) {
          let existingPage = pageMap.get(pageId);
          const existingSections = new Map(
            existingPage.sections.map((sec) => [sec.id, sec])
          );

          normalizedSectionsData.forEach((newSection) => {
            existingSections.set(newSection.id, newSection);
          });

          existingPage.sections = Array.from(existingSections.values());
          pageMap.set(pageId, existingPage);
        } else {
          pageMap.set(pageId, {
            pageId: pageId,
            sections: normalizedSectionsData
          });
        }

        this.formVale = Array.from(pageMap.values());
      }

      // Update page order and ensure proper sorting
      this.formVale = this.formVale
        .map((page) => {
          // If it's a new page, we should respect the order already set in handleAddpage
          if (this.isnewPage && page.pageId === this.selectedPageId) {
            return {
              ...page,
              sections: page.sections
                .map((section) => ({
                  ...section,
                  order: section.order || 0 // Ensure all sections have order
                }))
                .sort((a, b) => a.order - b.order)
            };
          } else {
            // For existing pages, continue with current logic
            const pageData = this.pages.find(
              (pg) => pg.questionBook.id === page.pageId
            );
            return {
              ...page,
              order: pageData
                ? pageData.order
                : page.order || this.formVale.length,
              sections: page.sections
                .map((section) => ({
                  ...section,
                  order: section.order || 0 // Ensure all sections have order
                }))
                .sort((a, b) => a.order - b.order)
            };
          }
        })
        .sort((a, b) => a.order - b.order);

      //RT 03APR25 - Reset the newPage flag after processing
      this.isnewPage = false;
    }
    console.log(
      "### Final Multi-Page Structure: ",
      JSON.stringify(this.formVale)
    );
  }

  // findElementByIdentifier(identifier) {
  //   for (const page of this.formVale) {
  //     for (const section of page.sections) {
  //       for (const question of section.subQuestions) {
  //         if (question.Id === identifier || question.key === identifier) {
  //           return question;
  //         }
  //       }
  //     }
  //   }
  //   return null;
  // }

  handleFinalDatatest(event) {
    this.formVale = JSON.parse(JSON.stringify(event.detail));
    //console.log("###formVale : " + JSON.stringify(this.formVale));
  }

  // VD 17Jan24 - form builder changes
  handleSave() {
    // Check if any page has an empty sections array
    const hasEmptySections = this.formVale.some(
      (page) => !page.sections || page.sections.length === 0
    );

    if (hasEmptySections) {
      this.showToast(
        "Error",
        "Please add at least one section in each page",
        "Error"
      );
      this.loading = false;
      return; // Stop execution, prevent API call
    }

    this.loading = true;
    this.isModalOpen = false;
    let data = JSON.stringify(this.formVale);
    console.log("###Data : " + data);
    formBuilder({
      inputId: this.recordId,
      formData: data
    })
      .then((result) => {
        let data = JSON.parse(result);
        let modelData = {};
        this.loading = false;
        if (data.ques.length > 0) {
          this.showToast(
            "Success",
            "Question Book Updated Successfully !",
            "Success"
          );
          location.reload();
        } else {
          this.showToast("Error", "Error in saving the record", "Error");
        }
        const modelValue = this.template
          .querySelector("c-custom-Model")
          .updateSave(modelData);
      })
      .catch((error) => {
        this.loading = false;
        //console.log("###Error : " + error);
        this.showToast("Error", error, "Error");
      });
  }

  preview() {
    if (this.formVale) {
      let data = {};
      data["isFormModel"] = true;
      data["formData"] = this.formVale.data;
      data["isModalOpen"] = true;
      data["heading"] = "Form";
      const model = this.template
        .querySelector("c-custom-Model")
        .updateForm(data);
    }
  }
  handlePreviewpage(event) {
    this.isPreview = event.detail.previewData.isPreview;
    //console.log("isPreview", this.isPreview);

    // Make sure the forms component gets the current page data
    //if (this.isPreview) {
    // Small timeout to ensure DOM updates before we access the forms component
    setTimeout(() => {
      const formsComponent = this.template.querySelector("c-fb-canvas");
      if (formsComponent) {
        const pageData = this.pageStateMap.get(this.selectedPageId);
        if (pageData) {
          formsComponent.updateForm(
            this.sectionMap,
            this.selectedPageId,
            pageData,
            this.selectedObject,
            this.pageTitleMap,
            null,
            this.pageActionMap //Actions/23Apr25/Thangarasu-add pageActionMap
          );
        }
      }
    }, 0);
    // }
  }

  generateKey() {
    return Math.random().toString(36).substr(2, 9);
  }
  // VD 17Jan24 - form builder changes
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  handleGetPageId(event) {
    // Synchronously provide pageId through callback
    if (event.detail && event.detail.callback && this.selectedPageId) {
      event.detail.callback(this.selectedPageId);
    }
  }
  // MA 16MAR25 -  Added handleAdd function
  handleAddpage(event) {
    // Create deep copies
    const currentJsonData = JSON.parse(JSON.stringify(this.jsonData));
    const currentFormVale = JSON.parse(JSON.stringify(this.formVale));

    const newPage = event.detail.pages[0];

    // Create the new page's sections - filtering out empty ones
    const newPageSections = newPage.records
      ?.map((section) => ({
        id: section.id,
        order: section.order,
        pageId: newPage.questionBook.id,
        question: this.qbMap.get(section.id),
        subQuestions: this.formatSubQuestions(
          this.qbMap.get(section.id)?.subQuestions || [],
          section.id
        )
      }))
      .filter((section) => section.id) || [
      // This filter removes empty sections
      {
        id: `Section${this.generateKey()}`,
        order: 1,
        question: { title: "New Section" },
        pageId: newPage.questionBook.id,
        subQuestions: [this.createDefaultSubQuestion("New Section")]
      }
    ];

    // Create the new page structure without empty sections
    const newPageStructure = {
      pageId: newPage.questionBook.id,
      sections: newPageSections,
      order: newPage.order || currentJsonData.pages.length + 1
    };

    // Update state
    this.jsonData = {
      ...currentJsonData,
      pages: [...currentJsonData.pages, newPage]
    };
    // AT 17Apr25  new page details updated in all maps
    this.formVale = [...currentFormVale, newPageStructure];

    this.pageOrderMap.set(newPage.questionBook.id, newPage.order);

    this.pageStateMap.set(newPage.questionBook.id, newPageSections);

    this.pageTitleMap.set(newPage.questionBook.id, newPage.title || "New Page");

    this.pages = [...this.pages, newPage];

    // Update UI
    this.selectedPageId = newPage.questionBook.id;
    this.pageOptions = [
      ...this.pageOptions,
      {
        label: `Page ${newPage.order}`,
        value: newPage.questionBook.id,
        order: newPage.order
      }
    ];

    // RT 03APR25 - Set the new page flag as TRUE
    this.isnewPage = true;
    this.loadPageSections(this.selectedPageId);

    this.handleInput({
      detail: {
        isPageTitle: true,
        data: newPage.title || "New Page",
        pageOrder: newPage.order,
        pageId: this.selectedPageId
      }
    });
  }

  // ASM 09Apr25 - Added handlePageDelete function
  handlePageDelete(event) {
    console.log("Page Delete Event:", JSON.stringify(event.detail));

    const deletedPageId = event.detail.deletedPageId;
    // AT 18pr25 to prevent deletion of last single page
    if (this.pages.length <= 1) {
      this.showToast("Error", "At least one saved page is required", "error");
      return;
    }

    console.log("Deleting Page ID:", deletedPageId);
    console.log("page order", this.pageOrderMap.get(deletedPageId));
    let deletedPageOrder = this.pageOrderMap.get(deletedPageId);
    let inputPageOrder = deletedPageOrder - 1;
    let inputPageId = Array.from(this.pageOrderMap.entries()).find(
      ([key, value]) => value === inputPageOrder
    )?.[0];

    // Handle properties update for any previous page type
    if (inputPageId) {
      this.handleInput({
        detail: {
          isPageTitle: true,
          data: this.pageTitleMap.get(inputPageId),
          pageOrder: inputPageOrder,
          pageId: inputPageId
        }
      });
    }

    if (deletedPageId.startsWith("page")) {
      const deletedPageIndex = this.pageOptions.findIndex(
        (p) => p.value === deletedPageId
      );
      if (deletedPageIndex === -1) {
        console.error("Page not found in options!");
        return;
      }

      this.jsonData.pages = this.jsonData.pages.filter(
        (p) => p.questionBook.id !== deletedPageId
      );
      this.pages = this.pages.filter(
        (p) => p.questionBook.id !== deletedPageId
      );

      // AT 17Apr25 Delete Page from all maps
      this.pageOrderMap.delete(deletedPageId);

      let newOrder = 1;
      const updatedPageOrderMap = new Map();

      for (const [pageId, _] of this.pageOrderMap.entries()) {
        updatedPageOrderMap.set(pageId, newOrder++);
      }

      this.pageOrderMap = updatedPageOrderMap;
      this.pageStateMap.delete(deletedPageId);
      this.pageTitleMap.delete(deletedPageId);

      this.jsonData.pages = this.jsonData.pages.map((p, idx) => {
        p.order = idx + 1;
        return p;
      });

      this.pages = this.pages.map((p, idx) => {
        p.order = idx + 1;
        return p;
      });

      this.formVale = this.formVale
        .filter((p) => p.pageId !== deletedPageId)
        .map((page, index) => ({
          ...page,
          order: index + 1
        }));

      this.pageOptions = this.pageOptions.filter(
        (p) => p.value !== deletedPageId
      );

      this.pageOptions = this.pageOptions.map((page, idx) => ({
        label: `Page ${idx + 1}`,
        value: page.value,
        order: idx + 1 //AT 11APR25 - for Pagination Footer
      }));

      const newPageIndex = deletedPageIndex > 0 ? deletedPageIndex - 1 : 0;
      this.selectedPageId = this.pageOptions[newPageIndex]?.value || null;

      console.log("After delete: ", JSON.stringify(this.jsonData.pages));
      this.loadPageSections(this.selectedPageId);
    } else if (deletedPageId.startsWith("a")) {
      // Count total active pages (both saved and dummy)
      const totalActivePages = this.pageOptions.length;
      if (totalActivePages <= 1) {
        this.showToast("Error", "At least one page is required", "error");
        return;
      }

      const deletedPageIndex = this.pageOptions.findIndex(
        (p) => p.value === deletedPageId
      );
      if (deletedPageIndex === -1) {
        console.error("Page not found in options!");
        return;
      }

      let orderCounter = 1;

      this.formVale = this.formVale.map((p) => {
        if (p.pageId === deletedPageId) {
          return { ...p, isDeleted: true }; // mark as deleted
        }
        return {
          ...p,
          order: orderCounter++
        };
      });

      //AT 17APR25 - to ensure deleted pages are skipped
      this.jsonData.pages = this.jsonData.pages.filter(
        (p) => p.questionBook.id !== deletedPageId
      );
      this.pages = this.pages.filter(
        (p) => p.questionBook.id !== deletedPageId
      );
      this.pageOrderMap.delete(deletedPageId);

      let newOrder = 1;
      const updatedPageOrderMap = new Map();

      for (const [pageId, _] of this.pageOrderMap.entries()) {
        updatedPageOrderMap.set(pageId, newOrder++);
      }

      this.pageOrderMap = updatedPageOrderMap;
      this.pageStateMap.delete(deletedPageId);
      this.pageTitleMap.delete(deletedPageId);

      this.jsonData.pages = this.jsonData.pages.map((p, idx) => {
        p.order = idx + 1;
        return p;
      });

      this.pages = this.pages.map((p, idx) => {
        p.order = idx + 1;
        return p;
      });

      this.pageOptions = this.pageOptions
        .filter((p) => {
          const fv = this.formVale.find((f) => f.pageId === p.value);
          return !fv?.isDeleted;
        })
        .map((p, idx) => ({
          label: `Page ${idx + 1}`,
          value: p.value,
          order: idx + 1 //AT 11APR25 - for Pagination Footer
        }));

      const newPageIndex = deletedPageIndex > 0 ? deletedPageIndex - 1 : 0;
      this.selectedPageId = this.pageOptions[newPageIndex]?.value || null;

      // Fix: Only try to handle input if selectedPageId is defined and inputPageId exists
      if (this.selectedPageId && inputPageId) {
        this.handleInput({
          detail: {
            isPageTitle: true,
            data: this.pageTitleMap.get(this.selectedPageId),
            pageOrder: this.pageOrderMap.get(this.selectedPageId),
            pageId: this.selectedPageId
          }
        });
      }

      console.log(
        "Page title: ",
        JSON.stringify(this.pageTitleMap.get(this.selectedPageId))
      );
      console.log(
        "Page order delete: ",
        JSON.stringify(this.pageOrderMap.get(this.selectedPageId))
      );
      console.log("After soft delete: ", JSON.stringify(this.formVale));

      this.loadPageSections(this.selectedPageId);
    } else {
      this.showToast("Error", "Cannot delete the last remaining page", "error");
    }
  }

  handleSaveEvent() {
    this.handleSave();
  }

  // Helper function to create a default sub-question
  createDefaultSubQuestion(title) {
    return {
      key: this.generateKey(),
      element: "Book",
      fieldNo: 1,
      label: title || "New Section",
      value: null,
      options: [],
      size: 12,
      styleClass: "slds-size_12-of-12",
      // Include all other required default properties
      uploadedFiles: [],
      columns: [],
      referenceField: "",
      uniqueIdentifier: "",
      subText: {},
      styles: {},
      isDependent: false,
      isHide: false,
      readOnly: false,
      isOptional: true,
      bookType: true,
      resultantflag: false,
      // All other boolean flags
      isText: false,
      isTextArea: false
      // ... rest of the properties
    };
  }

  dispatchFormCompleteEvent() {
    this.loading = false;
    fireEvent(this.wiredPageReferenceResult, "formbuilder_completed", {
      recordId: this.recordId,
      success: true
    });
  }

  @api refreshFormData() {
    if (this.recordId) {
      this.processForm();
      return true;
    }
    return false;
  }
 mapping = {
    "Book": "bookType",
    "Text": "isText",
    "Dropdown": "isPickList",
    "TextArea": "isTextArea",
    "DateTime": "isDateTime",
    "Date": "isDate",
    "Picklist": "isPickList",
    "File": "isFile",
    "Number": "isNumber",
    "Email": "isEmail",
    "Checkbox": "isCheckbox",
    "Search": "isSearch",
    "Image": "isImage",
    "Label": "isLabel",
    "Radio": "isRadio",
    "Table": "isTable"
};
//AT 10MAY25 for chat element visibility
 handleFG(event){
  this.ischatvisible = !this.ischatvisible
  }
 //AT 10MAY25 to handle ai chat conversation
  handleNewMessage(event){
    let new_message = event.detail.message;
    this.chatmessages.push(new_message);
    let current_page = this.formVale.find((page) => page.pageId === this.selectedPageId);
    console.log('generating form...');
    this.chatloading = true;
    generat_form({ prompt: new_message.message, chatHistory: this.chathistory,  pages:this.formVale, currentPage_id: this.selectedPageId, attachment_url: new_message.attachment_url }) 
    .then(result => {
        // console.log('Generated Form:',  JSON.stringify(result));
        let parsedResult = JSON.parse(result);
        const chatBot = this.template.querySelector('c-chat-bot');
            if (chatBot) {
                chatBot.handleResponse(parsedResult);
            }
        let messagefromai = parsedResult.message? parsedResult.message : parsedResult.error? parsedResult.error : "Sorry, I didn't understand that. Could you please rephrase?";
        let received_message = {
          id: Date.now(),
          senderName: 'ranger-fg',  
          class: 'message received',
          message: messagefromai,
        }
        let history = {
          role: "assistant", 
          content: [{"type": "text", "text": JSON.stringify(result)}]
        }
        this.chathistory.push(event.detail.history);
        this.chatmessages.push(received_message);
        this.chathistory.push(history);
 
    console.log('page')
    parsedResult?.upsertpageobjects?.forEach(page => {
        this.upsertPage(page);
    });
        console.log('page completed')
    // Upsert Sections
    console.log('section')
    parsedResult?.upsertsectionobjects?.forEach(section => {
        this.upsertSection(section);
    });
    console.log('section completed')
    // Upsert SubQuestions
    console.log('subquestion')
    parsedResult?.upsertsubquestionobjects?.forEach(subQuestion => {
        this.upsertsubquestion(subQuestion);
    });
    console.log('subquestion completed')
    // Deletion logic
    let pageIds = parsedResult?.deletepageobjects || [];
    let sectionIds = parsedResult?.deletesectionobjects || [];
    let subQuestionKeys = parsedResult?.deletesubquestionobjects || [];

    if (pageIds.length > 0) {
        this.deletePage(pageIds);
    }

    if (sectionIds.length > 0) {
        this.deleteSections(sectionIds);
    }

    if (subQuestionKeys.length > 0) {
        this.deleteSubQuestions(subQuestionKeys);
    }
    let new_pageid = this.formVale.find(p => p.pageId === this.selectedPageId)?.pageId;
    if (!new_pageid) {
      new_pageid = this.formVale[0]?.pageId;
    }
    this.selectedPageId = new_pageid;

    this.loadPageSections(this.selectedPageId);

}).then(() => {
  this.loading = false;
  this.chatloading = false;
})
    .catch(error => {
        console.error('Error generating form:', error);
    });

    
  }

  handleChatClose() {
    this.showChat = false;
  }

  payload = {
    "message": "Form generated successfully. Would you like any adjustments?",
    "upsertpageobjects": [
        {
            "id": "page1234abcd",
            "order": 1,
            "title": "Patient Enrollment Form"
        }
    ],
    "upsertsectionobjects": [
        {
            "id": "sectionabcd1234",
            "order": 1,
            "pageId": "page1234abcd",
            "title": "Patient Information"
        },
        {
            "id": "sectionefgh5678",
            "order": 2,
            "pageId": "page1234abcd",
            "title": "Contact Information"
        },
        {
            "id": "sectionijkl9012",
            "order": 3,
            "pageId": "page1234abcd",
            "title": "Prescriber Information"
        },
        {
            "id": "sectionmnop3456",
            "order": 4,
            "pageId": "page1234abcd",
            "title": "Order Details"
        },
        {
            "id": "sectionqrst7890",
            "order": 5,
            "pageId": "page1234abcd",
            "title": "Authorization & Consent"
        }
    ],
    "upsertsubquestionobjects": [
        {
            "element": "Text",
            "fieldNo": 2,
            "key": "ABCD1234",
            "label": "First Name",
            "placeholder": "First Name",
            "sectionId": "sectionabcd1234",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 3,
            "key": "EFGH5678",
            "label": "Middle Name",
            "placeholder": "Middle Name",
            "sectionId": "sectionabcd1234",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 4,
            "key": "IJKL9012",
            "label": "Last Name",
            "placeholder": "Last Name",
            "sectionId": "sectionabcd1234",
            "width": 6
        },
        {
            "element": "Date",
            "fieldNo": 5,
            "key": "MNOP3456",
            "label": "Date of Birth (MM/DD/YYYY)",
            "placeholder": "Date of Birth (MM/DD/YYYY)",
            "sectionId": "sectionabcd1234",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 2,
            "key": "QRST7890",
            "label": "Street Address",
            "placeholder": "Street Address",
            "sectionId": "sectionefgh5678",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 3,
            "key": "UVWX1234",
            "label": "City",
            "placeholder": "City",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 4,
            "key": "YZAB5678",
            "label": "State",
            "placeholder": "State",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 5,
            "key": "CDEF9012",
            "label": "Zip Code",
            "placeholder": "Zip Code",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 6,
            "key": "GHIJ3456",
            "label": "Phone Number",
            "placeholder": "Phone Number",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Email",
            "fieldNo": 7,
            "key": "KLMN7890",
            "label": "Email",
            "placeholder": "Email",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Dropdown",
            "fieldNo": 8,
            "key": "OPQR1234",
            "label": "Preferred Communication Type",
            "options": [
                {
                    "key": "abcd1111",
                    "value": "-- Select --"
                },
                {
                    "key": "efgh2222",
                    "value": "Phone - Home"
                },
                {
                    "key": "ijkl3333",
                    "value": "Phone - Work"
                },
                {
                    "key": "mnop4444",
                    "value": "Phone - Cell"
                },
                {
                    "key": "qrst5555",
                    "value": "Email"
                },
                {
                    "key": "uvwx6666",
                    "value": "Mail"
                }
            ],
            "placeholder": "Preferred Communication Type",
            "sectionId": "sectionefgh5678",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 2,
            "key": "STUV5678",
            "label": "First Name",
            "placeholder": "First Name",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 3,
            "key": "WXYZ9012",
            "label": "Last Name",
            "placeholder": "Last Name",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 4,
            "key": "ABCD2345",
            "label": "NPI #",
            "placeholder": "NPI #",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 5,
            "key": "EFGH6789",
            "label": "HCP License",
            "placeholder": "HCP License",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 6,
            "key": "IJKL0123",
            "label": "Practice Name",
            "placeholder": "Practice Name",
            "sectionId": "sectionijkl9012",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 7,
            "key": "MNOP4567",
            "label": "Street Address",
            "placeholder": "Street Address",
            "sectionId": "sectionijkl9012",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 8,
            "key": "QRST8901",
            "label": "City",
            "placeholder": "City",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 9,
            "key": "UVWX2345",
            "label": "State",
            "placeholder": "State",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 10,
            "key": "YZAB6789",
            "label": "Zip Code",
            "placeholder": "Zip Code",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Email",
            "fieldNo": 11,
            "key": "CDEF0123",
            "label": "Email",
            "placeholder": "Email",
            "sectionId": "sectionijkl9012",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 12,
            "key": "GHIJ4567",
            "label": "Fax Number",
            "placeholder": "Fax Number",
            "sectionId": "sectionijkl9012",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 2,
            "key": "KLMN8901",
            "label": "Prescribed Dosage",
            "placeholder": "Prescribed Dosage",
            "sectionId": "sectionmnop3456",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 3,
            "key": "OPQR2345",
            "label": "Frequency (sessions per week)",
            "placeholder": "Frequency (sessions per week)",
            "sectionId": "sectionmnop3456",
            "width": 6
        },
        {
            "element": "Number",
            "fieldNo": 4,
            "key": "STUV6789",
            "label": "Duration (rental months)",
            "placeholder": "Duration (rental months)",
            "sectionId": "sectionmnop3456",
            "width": 6
        },
        {
            "element": "TextArea",
            "fieldNo": 5,
            "key": "WXYZ0123",
            "label": "Clinical Rationale",
            "placeholder": "Clinical Rationale",
            "sectionId": "sectionmnop3456",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 6,
            "key": "ABCD4567",
            "label": "ICD-10 Code",
            "placeholder": "ICD-10 Code",
            "sectionId": "sectionmnop3456",
            "width": 6
        },
        {
            "element": "TextArea",
            "fieldNo": 7,
            "key": "EFGH8901",
            "label": "Additional Rationale",
            "placeholder": "Additional Rationale",
            "sectionId": "sectionmnop3456",
            "width": 12
        },
        {
            "element": "Text",
            "fieldNo": 2,
            "key": "IJKL2345",
            "label": "Patient or Legal Representative Signature",
            "placeholder": "Patient or Legal Representative Signature",
            "sectionId": "sectionqrst7890",
            "width": 6
        },
        {
            "element": "Date",
            "fieldNo": 3,
            "key": "MNOP6789",
            "label": "Date",
            "placeholder": "Date",
            "sectionId": "sectionqrst7890",
            "width": 6
        },
        {
            "element": "Text",
            "fieldNo": 4,
            "key": "QRST0123",
            "label": "Patient Printed Name",
            "placeholder": "Patient Printed Name",
            "sectionId": "sectionqrst7890",
            "width": 12
        }
    ]
}


    // --------- CRUD for Pages ---------
upsertPage(page) {
    let pageIndex = -1
    if(page && page.id){
      pageIndex = this.formVale.findIndex(p => p.pageId === page.id);
    }

    if (pageIndex !== -1) {
        // Page exists, update it
        let existingPage = this.formVale[pageIndex];
        // existingPage.pageId = page?.id || existingPage.pageId;
        existingPage.order = page?.order || existingPage.order;
        existingPage.title = page?.title || existingPage.title;
        this.formVale.splice(pageIndex, 1);
        this.formVale.splice(existingPage.order - 1, 0, existingPage);
        this.reorder(this.formVale);
        this.updatestate(existingPage);
    } else {
        // Page does not exist, create new
        let newPage = {
            pageId: page?.id || `page${this.generateKey()}`,
            order: page?.order || this.formVale.length + 1,
            title: page?.title || 'New Page',
            sections: [],
            actions: []
        };
            console.log('created');
        this.formVale.splice(newPage.order - 1, 0, newPage);
        this.selectedPageId = newPage.pageId;
        this.reorder(this.formVale);
        this.updatestate(newPage);
    }
    this.formVale = [...this.formVale];//due to splice inconsistency need to know why

    // // Optional: Adjust order after upsert to ensure order consistency
    // this.formVale.forEach((page, idx) => {
    //     page.order = idx + 1;
    // });
}
updatestate(newPage){
      console.log('update ulla');
    // AT 17Apr25  new page details updated in all maps

    this.pageOrderMap.set(newPage.pageId, newPage.order);

    this.pageStateMap.set(newPage.pageId, newPage.sections);

    this.pageTitleMap.set(newPage.pageId, newPage.title || "New Page");

        let optionIndex = this.pageOptions.findIndex(option => option.value === newPage.pageId);
        if (optionIndex !== -1) {
            this.pageOptions.splice(optionIndex, 1);
        }

        // Insert the new option
        let newPageOption = {
            label: `Page ${newPage.order}`,
            value: newPage.pageId,
            order: newPage.order
        };
        this.pageOptions.splice(newPage.order - 1, 0, newPageOption);

        // FORCE REACTIVITY by creating a new array reference
        this.pageOptions.forEach((option, optionIndex) => {
          option.label =  `Page ${optionIndex + 1}`;
          option.order = optionIndex + 1;
        })
        this.pageOptions = [...this.pageOptions];

        console.log('updated', JSON.stringify(this.pageOptions));

}
deleteStateUpdate(pageIds) {
    const idsToDelete = new Set(pageIds);

    pageIds.forEach(pageId => {
        this.pageOrderMap.delete(pageId);
        this.pageStateMap.delete(pageId);
        this.pageTitleMap.delete(pageId);
    });

    this.pageOptions = this.pageOptions.filter(option => !idsToDelete.has(option.value));

    this.pageOptions.forEach((option, index) => {
        option.label = `Page ${index + 1}`;
        option.order = index + 1;
    });

    this.pageOptions = [...this.pageOptions];

    console.log('Updated Page Options:', JSON.stringify(this.pageOptions));
}

    deletePage(pageIds) {
        
      let orderCounter = 1;

      this.formVale = this.formVale.map((p) => {
        if (pageIds.includes(p.pageId)) {
          return { ...p, isDeleted: true }; // mark as deleted
        }
        return {
          ...p,
          order: orderCounter++
        };
      });
      this.deleteStateUpdate(pageIds);
    }

    // --------- CRUD for Sections ---------
    upsertSection(section) {
      if(!section.pageId){
        console.log('section must have a pageId');
        return;
      } 
      let New_page = this.formVale.find(p => p.pageId === section.pageId)
      if(!New_page){
        console.log('page not found')
        return;
      }
      let sectionIndex = -1;
      let existing_page = null;
      if(section && section.id){
        existing_page = this.formVale.find(p => p.sections.some(s => s.id === section.id));
        if(existing_page){
          sectionIndex = existing_page.sections.findIndex(s => s.id === section.id)
        }
      }
      console.log("==-1")
      if(sectionIndex !=-1){
        let existingSection = existing_page?.sections[sectionIndex];
        existingSection.pageId = section?.pageId || existingSection.pageId;
        existingSection.order = section?.order || existingSection.order;
        existingSection.question.title = section?.title || existingSection.question.title;

        existing_page.sections.splice(sectionIndex, 1);
        New_page.sections.splice(existingSection.order - 1, 0, existingSection);
        this.reorder(existing_page.sections);
        this.reorder(New_page.sections);
        this.updatestate(existing_page);
      }else{
        console.log("else");
        let newSection = {
          id: section?.id || `section${this.generateKey()}`,
          pageId: section?.pageId,
          order: section?.order || New_page.sections.length + 1,
          question: { title: section?.title || 'New Section' },
          subQuestions: [this.createDefaultSubQuestion(section?.title)],
          actions: [],
          style: {}
        };
              console.log("else ok")

        New_page.sections.splice(newSection.order - 1, 0, newSection);
        console.log("splice")
        this.reorder(New_page.sections);
        console.log("reorder")
      }
      this.updatestate(New_page);
      console.log("update state")

    }

    deleteSections(sectionIds) {
      this.formVale = this.formVale.map((p) => {
        if (p.sections) {
          p.sections = p.sections.filter(sec => !sectionIds.includes(sec.id));
          this.reorder(p.sections);
          this.updatestate(p);
        }
        return p;
      });
    }

    // --------- CRUD for SubQuestions ---------
    upsertsubquestion(subQuestion){
      if(!subQuestion?.sectionId && !subQuestion?.element){
        return;
      }
      let New_page = this.formVale.find(p => p.sections.some(s => s.id === subQuestion.sectionId));
      let New_section = New_page?.sections.find(s => s.id === subQuestion.sectionId);
      if(!New_section){
        return;
      }

      let existing_page = null;
      let existing_section = null;
      let subQuestionIndex = -1;

      if(subQuestion && subQuestion.key){
        existing_page = this.formVale.find(page => page.sections.some(section => section.subQuestions.some(sq => sq.key === subQuestion.key)));
        if(existing_page){
          existing_section = existing_page.sections.find(section => section.subQuestions.some(sq => sq.key === subQuestion.key));
        }
        if(existing_section){
          subQuestionIndex = existing_section?.subQuestions.findIndex(s => s.key === subQuestion.key);

      }
    }

      let Tablecolumns = subQuestion?.columns || [];
      if(subQuestionIndex !=-1){
        
        let existingsubQuestion = existing_section?.subQuestions[subQuestionIndex];//temporarily**
        Tablecolumns = this.normalizeTableColumns(Tablecolumns, existingsubQuestion?.columns || []);

        existingsubQuestion.placeholder = subQuestion?.placeholder || existingsubQuestion.placeholder;
        existingsubQuestion.helpText = subQuestion?.helpText || existingsubQuestion.helpText;
        existingsubQuestion.element = subQuestion?.element || existingsubQuestion.element;
        existingsubQuestion.fieldNo = subQuestion?.fieldNo || existingsubQuestion.fieldNo;
        existingsubQuestion.label = subQuestion?.label || existingsubQuestion.label;
        existingsubQuestion.value = subQuestion?.value || existingsubQuestion.value;
        existingsubQuestion.options = subQuestion?.options || existingsubQuestion.options;
        existingsubQuestion.uploadedFiles = subQuestion?.uploadedFiles || existingsubQuestion.uploadedFiles;
        existingsubQuestion.columns = Tablecolumns;
        existingsubQuestion.referenceField = subQuestion?.referenceField || existingsubQuestion.referenceField;
        existingsubQuestion.uniqueIdentifier = subQuestion?.uniqueIdentifier || existingsubQuestion.uniqueIdentifier;
        existingsubQuestion.subText = subQuestion?.subText || existingsubQuestion.subText;

        existingsubQuestion.style = {
            showLabel: subQuestion?.style?.showLabel ?? existingsubQuestion.style.showLabel,
            isHead: subQuestion?.style?.isHead ?? existingsubQuestion.style.isHead,
            isFoot: subQuestion?.style?.isFoot ?? existingsubQuestion.style.isFoot,
            isHeader: subQuestion?.style?.isHeader ?? existingsubQuestion.style.isHeader,
            isFooter: subQuestion?.style?.isFooter ?? existingsubQuestion.style.isFooter,
            key: subQuestion?.style?.key || existingsubQuestion.style.key
        };

        existingsubQuestion.size = subQuestion?.size || existingsubQuestion.size;
        existingsubQuestion.isHide = subQuestion?.isHide ?? existingsubQuestion.isHide;
        existingsubQuestion.readOnly = subQuestion?.readOnly ?? existingsubQuestion.readOnly;
        existingsubQuestion.styleClass = subQuestion?.styleClass || existingsubQuestion.styleClass;
        existingsubQuestion.isOptional = subQuestion?.isOptional ?? existingsubQuestion.isOptional;
        existingsubQuestion.bookType = subQuestion?.bookType ?? existingsubQuestion.bookType;
        existingsubQuestion.isText = subQuestion?.isText ?? existingsubQuestion.isText;
        existingsubQuestion.isTextArea = subQuestion?.isTextArea ?? existingsubQuestion.isTextArea;
        existingsubQuestion.isDateTime = subQuestion?.isDateTime ?? existingsubQuestion.isDateTime;
        existingsubQuestion.isDate = subQuestion?.isDate ?? existingsubQuestion.isDate;
        existingsubQuestion.isPickList = subQuestion?.isPickList ?? existingsubQuestion.isPickList;
        existingsubQuestion.isFile = subQuestion?.isFile ?? existingsubQuestion.isFile;
        existingsubQuestion.isNumber = subQuestion?.isNumber ?? existingsubQuestion.isNumber;
        existingsubQuestion.isEmail = subQuestion?.isEmail ?? existingsubQuestion.isEmail;
        existingsubQuestion.isCheckbox = subQuestion?.isCheckbox ?? existingsubQuestion.isCheckbox;
        existingsubQuestion.isSearch = subQuestion?.isSearch ?? existingsubQuestion.isSearch;
        existingsubQuestion.isImage = subQuestion?.isImage ?? existingsubQuestion.isImage;
        existingsubQuestion.isLabel = subQuestion?.isLabel ?? existingsubQuestion.isLabel;
        existingsubQuestion.isRadio = subQuestion?.isRadio ?? existingsubQuestion.isRadio;
        existingsubQuestion.isTable = subQuestion?.isTable ?? existingsubQuestion.isTable;
        existingsubQuestion.imgSrc = subQuestion?.imgSrc || existingsubQuestion.imgSrc;
        
        existing_section.subQuestions.splice(subQuestionIndex, 1);
        New_section.subQuestions.splice(existingsubQuestion.fieldNo - 1, 0, existingsubQuestion);
        this.reorder(existing_section.subQuestions);
        this.reorder(New_section.subQuestions);
        this.updatestate(existing_page);

      }else{

        let elementType = this.mapping[subQuestion.element];
        Tablecolumns = this.normalizeTableColumns(Tablecolumns);

        let newSubQuestion = {
            key: subQuestion?.key || this.generateKey(),
            sectionId: subQuestion?.sectionId,
            element: subQuestion.element,
            placeholder: subQuestion?.placeholder || '',
            helpText: subQuestion?.helpText || '',
            fieldNo: parseInt(subQuestion?.fieldNo || New_section.subQuestions.length + 1),
            label: subQuestion?.label || subQuestion.element,
            value: subQuestion?.value || null,
            options: subQuestion?.options || [],
            uploadedFiles: subQuestion?.uploadedFiles || [],
            columns: Tablecolumns,
            referenceField: subQuestion?.referenceField || '',
            uniqueIdentifier: subQuestion?.uniqueIdentifier || '',
            subText: subQuestion?.subText || '',
            style: {
                showLabel: subQuestion?.style?.showLabel ?? true,
                isHead: subQuestion?.style?.isHead ?? false,
                isFoot: subQuestion?.style?.isFoot ?? false,
                isHeader: subQuestion?.style?.isHeader ?? false,
                isFooter: subQuestion?.style?.isFooter ?? false,
                key: subQuestion?.style?.key || this.generateKey()
            },
            size: parseInt(subQuestion?.width || 6),
            isHide: subQuestion?.isHide ?? false,
            readOnly: subQuestion?.readOnly ?? false,
            styleClass: `slds-size_${parseInt(subQuestion?.width || 6)}-of-12`,
            isOptional: subQuestion?.isOptional ?? true,
            imgSrc: subQuestion?.imgSrc || '',
            isDependent: subQuestion?.isDependent ?? false,
            resultantflag: subQuestion?.resultantflag ?? false,

            bookType: elementType === 'bookType',
            isText: elementType === 'isText',
            isPickList: elementType === 'isPickList',
            isTextArea: elementType === 'isTextArea',
            isDateTime: elementType === 'isDateTime',
            isDate: elementType === 'isDate',
            isFile: elementType === 'isFile',
            isNumber: elementType === 'isNumber',
            isEmail: elementType === 'isEmail',
            isCheckbox: elementType === 'isCheckbox',
            isSearch: elementType === 'isSearch',
            isImage: elementType === 'isImage',
            isLabel: elementType === 'isLabel',
            isRadio: elementType === 'isRadio',
            isTable: elementType === 'isTable'
        };

        New_section.subQuestions.splice(newSubQuestion.fieldNo - 1, 0, newSubQuestion);
        this.reordersubquestions(New_section.subQuestions);

      }
      this.updatestate(New_page);

    }

    deleteSubQuestions(subQuestionKeys) {
      this.formVale = this.formVale.map((p) => {
        if (p.sections) {
          p.sections = p.sections.map(sec => {
            if (sec.subQuestions) {
              sec.subQuestions = sec.subQuestions.filter(sq => !subQuestionKeys.includes(sq.key));
              this.reordersubquestions(sec.subQuestions);
              this.updatestate(p);
            }
            return sec;
          });
        }
        return p;
      });

    }
    //---------------reordering pages, sections, subquestions------------
    reorder(list){
      list.forEach((item, itemIndex) => {
          item.order = itemIndex + 1;
        })

    }
    reordersubquestions(subquestions){
      subquestions.forEach((subquestion, subquestionIndex) => {
        subquestion.fieldNo = subquestionIndex + 1;
      })
    }
normalizeTableColumns(columns = [], existingColumns = []) {
    // Build a map for faster lookup
    const existingColumnMap = new Map(existingColumns.map(item => [item.key, item]));

    // Normalize columns
    let normalizedColumns = columns.map((column, index) => {
        const existingColumn = existingColumnMap.get(column.key) || {};

        return {
            key: column.key || existingColumn.key || this.generateUniqueKey(),
            id: column.id || existingColumn.id || "",
            label: column.label || existingColumn.label || 'Number',
            type: column.type || existingColumn.type || 'Number',
            isEditable: column.isEditable !== undefined ? column.isEditable :
                (existingColumn.isEditable !== undefined ? existingColumn.isEditable : true),
            isDeletable: column.isDeletable !== undefined ? column.isDeletable :
                (existingColumn.isDeletable !== undefined ? existingColumn.isDeletable : true),
            isdeleted: column.isdeleted !== undefined ? column.isdeleted :
                (existingColumn.isdeleted !== undefined ? existingColumn.isdeleted : false),
            showDelete: column.showDelete !== undefined ? column.showDelete :
                (existingColumn.showDelete !== undefined ? existingColumn.showDelete : false),
            fieldNo: column.fieldNo || existingColumn.fieldNo || index + 1,
            referenceField: column.referenceField || existingColumn.referenceField || '',
            element: column.element || existingColumn.element || 'Number',
            placeholder: column.placeholder || existingColumn.placeholder || '',
            size: column.size || existingColumn.size || 12,
            value: column.value || existingColumn.value || null,
            options: column.options || existingColumn.options || [],
            uploadedFiles: column.uploadedFiles || existingColumn.uploadedFiles || [],
            subText: column.subText || existingColumn.subText || '',
            style: column.style || existingColumn.style || '',
            isHide: column.isHide !== undefined ? column.isHide :
                (existingColumn.isHide !== undefined ? existingColumn.isHide : false),
            readOnly: column.readOnly !== undefined ? column.readOnly :
                (existingColumn.readOnly !== undefined ? existingColumn.readOnly : false),
            styleClass: column.styleClass || existingColumn.styleClass || 'slds-size_6-of-12',
            isOptional: column.isOptional !== undefined ? column.isOptional :
                (existingColumn.isOptional !== undefined ? existingColumn.isOptional : true),
            isText: column.isText !== undefined ? column.isText :
                (existingColumn.isText !== undefined ? existingColumn.isText : false),
            isTextArea: column.isTextArea !== undefined ? column.isTextArea :
                (existingColumn.isTextArea !== undefined ? existingColumn.isTextArea : false),
            isDateTime: column.isDateTime !== undefined ? column.isDateTime :
                (existingColumn.isDateTime !== undefined ? existingColumn.isDateTime : false),
            isDate: column.isDate !== undefined ? column.isDate :
                (existingColumn.isDate !== undefined ? existingColumn.isDate : false),
            isPickList: column.isPickList !== undefined ? column.isPickList :
                (existingColumn.isPickList !== undefined ? existingColumn.isPickList : false),
            isNumber: column.isNumber !== undefined ? column.isNumber :
                (existingColumn.isNumber !== undefined ? existingColumn.isNumber : true),
            isCheckbox: column.isCheckbox !== undefined ? column.isCheckbox :
                (existingColumn.isCheckbox !== undefined ? existingColumn.isCheckbox : false),
            isSearch: column.isSearch !== undefined ? column.isSearch :
                (existingColumn.isSearch !== undefined ? existingColumn.isSearch : false),
            isImage: column.isImage !== undefined ? column.isImage :
                (existingColumn.isImage !== undefined ? existingColumn.isImage : false),
            imgSrc: column.imgSrc || existingColumn.imgSrc || '',
            isTableColumn: column.isTableColumn !== undefined ? column.isTableColumn :
                (existingColumn.isTableColumn !== undefined ? existingColumn.isTableColumn : true),
            isTableTypeList: column.isTableTypeList !== undefined ? column.isTableTypeList :
                (existingColumn.isTableTypeList !== undefined ? existingColumn.isTableTypeList : true),
            outputFlag: column.outputFlag !== undefined ? column.outputFlag :
                (existingColumn.outputFlag !== undefined ? existingColumn.outputFlag : false),
            resultantflag: column.resultantflag !== undefined ? column.resultantflag :
                (existingColumn.resultantflag !== undefined ? existingColumn.resultantflag : false),
            orderbyflag: column.orderbyflag !== undefined ? column.orderbyflag :
                (existingColumn.orderbyflag !== undefined ? existingColumn.orderbyflag : false),
            filterflag: column.filterflag !== undefined ? column.filterflag :
                (existingColumn.filterflag !== undefined ? existingColumn.filterflag : false),
            searchflag: column.searchflag !== undefined ? column.searchflag :
                (existingColumn.searchflag !== undefined ? existingColumn.searchflag : false),
            objectApiName: column.objectApiName || existingColumn.objectApiName || '',
            fieldApiName: column.fieldApiName || existingColumn.fieldApiName || '',
            tableHeadStyle: column.tableHeadStyle || existingColumn.tableHeadStyle || '',
            tableDataStyle: column.tableDataStyle || existingColumn.tableDataStyle || '',
            fieldMetaId: column.fieldMetaId || existingColumn.fieldMetaId || ''
        };
    });
    // delete missing existing columns by marking isdeleted = true
    if (columns.length > 0 && existingColumns.length > 0) {
        existingColumns.forEach(existingColumn => {
            const isExist = columns.some(col => col.key === existingColumn.key);
            if (!isExist) {
                normalizedColumns.push({
                    ...existingColumn,
                    isdeleted: true 
                });
            }
        });
    }
    // Sort the columns for consistency
    normalizedColumns.sort((a, b) => {
        return a["fieldNo"] - b["fieldNo"];
    });

    return normalizedColumns;
}


}