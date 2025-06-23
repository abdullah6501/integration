import { LightningElement, track, wire, api } from 'lwc';
//import getRecordTypeId from '@salesforce/apex/InvoiceFormController.getRecordTypeId';
import getProductList from '@salesforce/apex/InvoiceFormController.getProductList';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
//import BillingCountryCode from '@salesforce/schema/Account.BillingCountryCode';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import getAccBankInfo from "@salesforce/apex/InvoiceFormController.getAccBankInfo";
//import getCurrencyInWords from "@salesforce/apex/InvoiceFormController.getCurrencyInWords";
import getInvoiceFormData from "@salesforce/apex/InvoiceFormController.getInvoiceFormData";
import getMainTaxOptions from "@salesforce/apex/InvoiceFormController.getMainTaxOptions";
import getChildTaxOptions from '@salesforce/apex/InvoiceFormController.getChildTaxOptions';
import getAllChildTaxOptions from '@salesforce/apex/InvoiceFormController.getAllChildTaxOptions';
import saveInvoiceRecord from "@salesforce/apex/InvoiceFormController.saveInvoiceRecord";
import validateInvoiceRecord from "@salesforce/apex/InvoiceFormController.validateInvoiceRecord";
import clearanceInvoice from "@salesforce/apex/InvoiceFormController.clearanceInvoice";
import emailViewCount from "@salesforce/apex/InvoiceFormController.emailViewCount";
import getAuthList from '@salesforce/apex/InvoiceFormController.getAuthList';
import getInvoiceType from '@salesforce/apex/InvoiceFormController.getInvoiceType';
import getInvoiceNameType from '@salesforce/apex/InvoiceFormController.getInvoiceNameType';
//import {LightningPrompt} from 'lightning/prompt';
import {NavigationMixin} from 'lightning/navigation';
//import base64PDF from './example.js';
//import FILE_PREVIEW_RESOURCE from '@salesforce/resourceUrl/lightningFilePreview';
import LightningModal from 'lightning/modal';
import SystemModstamp from '@salesforce/schema/Account.SystemModstamp';





export default class InvoiceForm extends NavigationMixin(LightningElement) {

    @track checkboxjournalflag = false;
    @track invoicerecordId;
    @track invoicerecordIdAfter;
    // @track invoicerecordIdValid;
    @api recordId;
    @track invWrapObj;
    sendEmailFlag = false;
    popupDivStyle;
    journalEntryDebit;
    //@api ParentinvoiceId = '';
    @track dragStart;
    @track spinnerFlag = false;
    @track isGreyedOut = false;
    @track ready = false;
    formDisableFlag;
    //invoiceId = 'a0tDn000001hWtjIAE';
    @api invoiceId = '';
    @track isExecutedOnce = false;
    @track invoiceItemList = [];
    errorMessage;
    sendEmailFlag = false;
    serviceDate = null;
    pdtId = null;
    pdtDraftName = null;
    isKnownPdt = false;
    hsn = null;
    description = null;
    qty = null;
    rate = null;
    amt = null;
    tax = null;
    taxId = null;
    primaryContactEmail;
    ccEmailAddressesStr;
    tempCcEmailAddressesStr;
    bccEmailAddressesStr;
    tempBccEmailAddressesStr;
    calculatedSubTotal = 0.00;
    //@track grandTotal = 0.00;
    //showSubTotalSection = false;
    chosenParentTaxOption = 'Inclusive of Tax';
    accMdtInfo = null;
    msgOnInv = null;
    companyName = null;
    termsAndCond = null;
    currencyCode = null;
    currencyCodeName = null;
    invNumber = null;
    currencyInWords = null
    msgOnStmt = null;
    //showGrandTotalSection = false;
    hideSubTaxesSection = false;
    showCcBccSec = false;
    @track resultantSubTaxArray = [{"Id" : null,  "Label" : null, "value": null}];
    taxPercentageOptions = [];
    currentSelectedTaxLabel;
    @track finalSubTaxesInfoJson = [];
    @track finalSubTaxesInfoMap = new Map();
    @track subTaxLabelMap = new Map();
    @track subTaxWholeMap = new Map();
   
    @wire(getAllChildTaxOptions) allChildTaxInfoResp;
    @wire(getMainTaxOptions,{countryName:'India'}) handleGetTaxOptionsResult(result){
        // ////console.log("Inside the handleGetTaxOptionsResult");
        // ////console.log(result);
        // ////console.log(result.data);
        ////console.log(typeof result.data);
        if(result.data) {   
            this.taxPercentageOptions = result.data;
            // ////console.log("taxPercentageOptions.length = "+this.taxPercentageOptions.length);
            // ////console.log('this.taxPercentageOptions = ',this.taxPercentageOptions);
        }
    };
    @track parentAccountSelectedRecord = [];
    @track parentContactSelectedRecord = [];
    chosenTerm = '15';
    chosenTermLabel = 'Net 15';
    @track invoiceDate = new Date().toISOString().substring(0, 10);
    @track dueDate = new Date(new Date().setDate(new Date().getDate() + 15)).toISOString().substring(0, 10);
    selectedCountry = 'IN';
    
    ccListLength = 0;
    bccListLength = 0;
    //previewPdfFlag = false;
    vfPageURLToPreview;
    hideInputForPdtSerCurrentRow = true;
    //@track pdtList;
    @track pdtComboBoxList = [];
    
    pdtListRenderingFlag = false;
    @wire(getProductList) handleGetProductList(result){
        
        if(result.data){
            ////console.log('result.data.length'+result.data.length);
            for(let i=0; i<result.data.length; i++){
                ////console.log('Name = '+result.data[i].Name);
                this.pdtComboBoxList.push({label:result.data[i].Name, value:result.data[i].Id});
            }
            this.pdtComboBoxList.push({label:'+ Add New', value:'_new_'});
            this.pdtListRenderingFlag = true;
        }
    };
    @track autComboBoxList = [];
    @track authroizedSignature;

    @wire(getAuthList)
    wiredMetadata({ error, data }) {
        if (data) {
            this.autComboBoxList = data.map((record) => ({
                label: record.MasterLabel,
                value: record.MasterLabel
            }));
        } else if (error) {
            ////console.error('Error fetching custom metadata:', error);
        }
    }

    @track invoicetypeList = [];
    @track invoiceType;

    @wire(getInvoiceType)
    wiredInvTypeData({ error, data }) {
        if (data) {
            this.invoicetypeList = data;
        } else if (error) {
            // console.error('Error fetching custom metadata:', error);
        }
    }

    handleInvTypeChange(event){
        this.invoiceType = event.target.value;
        console.log('invoiceType = '+this.invoiceType);
    }

    @track invoiceNametypeList = [];
    @track invoiceNameType;

    @wire(getInvoiceNameType)
    wiredInvNameTypeData({ error, data }) {
        if (data) {
            this.invoiceNametypeList = data;
        } else if (error) {
            // console.error('Error fetching custom metadata:', error);
        }
    }

    handleInvNameTypeChange(event){
        this.invoiceNameType = event.target.value;
        console.log('invoiceNameType = '+this.invoiceNameType);
    }

    handleCheckboxChange(event) {         
        this.checkboxjournalflag = event.target.checked; 
        ////console.log('this.isChecked = '+this.checkboxjournalflag);
    }

    closeAction() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Invoice__c',
                actionName: 'list'
            },
        });
    }
    constructor() {
        ////console.log('Inside the constructor');
        super();
        ////console.log(this.recordId);
        //this.recordId = 'a0tDn000001hWtjIAE';
    }

    /*get fetchPdtComboList(){
        ////console.log("fetchPdtComboList");
        ////console.log("pdtList.length = "+this.pdtList.length);
        let pdtComboList = [];
        let i = 0;
        this.pdtList.forEach(ele =>{
                ////console.log("Inside the for loop = Name: "+ele.Name+" Id: "+ele.Id);
                pdtComboList.push({label:ele.Name, value:ele.Id});
                i++;
            });
        
        return pdtComboList;
    }*/

    /*get currencyInWords(){
        if(!this.grandTotal || this.grandTotal <= 0) return 'Zero Only';
        getCurrencyInWords(
                {totalInvAmt: this.grandTotal}
            )
            .then((result) => {
                //console.log("Inside the getCurrencyInWords");
                //console.log(result);
                let currencyInWordsVal = result + ' Only';
                //console.log(' currencyInWordsVal = '+currencyInWordsVal);
                return currencyInWordsVal;
            })
            .catch((error) => {
                //console.log("###Error : " + error.body.message);
                return 'Zero Only';
            });
    }*/

    get fetchTaxOptions(){
        ////console.log("fetchTaxOptions");
        ////console.log("this.grandTotal "+this.grandTotal);
        ////console.log("taxPercentageOptions.length = "+this.taxPercentageOptions.length);
        let mainPercentageOptions = [];
        let i = 0;
        this.taxPercentageOptions.forEach(ele =>{
                ////console.log("Inside the for loop = Name: "+ele.Name+" Tax_Percentage__c: "+ele.Tax_Percentage__c);
                mainPercentageOptions.push({label:ele.Name, value:ele.Tax_Percentage__c+"%"});
                //this.subTaxLabelMap.set(ele.Tax_Percentage__c+"%",ele.Name);
                this.subTaxLabelMap.set(ele.Tax_Percentage__c+"%",ele);
                this.subTaxWholeMap.set(ele.Name,ele.Id);
                ////console.log("Inside the for loop = Name: "+ele.Name+" Id: "+ele.Id);
                /*////console.log("Inside the for loop = Name: "+mainPercentageOptions[i].label+
                " Tax_Percentage__c: "+mainPercentageOptions[i].value);*/
                i++;
            });
        
        ////console.log('this.subTaxLabelMap.size = ',this.subTaxLabelMap.size);
        ////console.log('this.subTaxWholeMap.size = ',this.subTaxWholeMap.size);
        
        ////console.log("this.recordId = "+this.recordId);
        ////console.log('this.invoiceItemList.length = '+this.invoiceItemList.length);
        if(this.recordId && !this.isExecutedOnce && this.invoiceItemList.length > 0){
            ////console.log('Invoice id not null cond in fetchTaxOptions');
            //this.isExecutedOnce = true;
            this.reCalculateSubTaxInfoMap(true);
        }

        ////console.log('mainPercentageOptions = ',mainPercentageOptions);

        return mainPercentageOptions;
    }

    get disableFlagForPdtNameSec(){
        return (this.hideInputForPdtSerCurrentRow || this.formDisableFlag)
    }

    /*get hideBalanceDueSecOnTop(){
        if(this.recordId && this.isExecutedOnce){
            return false;
        }else if(!this.recordId){
            return false;
        }
        return true;
    }*/



    connectedCallback() {
        ////console.log(this.heckboxjournalflag);
        //this.recordId = 'a0tDn000001hWtjIAE';
        ////console.log('Inside connected callback');
        ////console.log("this.recordId = "+this.recordId);
        if(!this.recordId){
            getAccBankInfo(
                //RP - 02May2023 - Commanded since we will be having only one row in this table here after
                //{accName: "Ranger Technologies Private Limited"}
            )
            .then((result) => {
                // //console.log("Inside the getAccBankInfo");
                // //console.log(result);
                if(result.length > 0 ){
                    this.accMdtInfo = result[0];
                    this.msgOnInv = "Bank Information:";
                    this.msgOnInv += "\nAccount Number: "+this.accMdtInfo.Account_Number__c;
                    this.msgOnInv += "\nAccount Type: "+this.accMdtInfo.Account_Type__c;
                    this.msgOnInv += "\nIFSC Code: "+this.accMdtInfo.IFSC_Code__c;
                    this.msgOnInv += "\nBranch: "+this.accMdtInfo.Branch__c;
                    this.termsAndCond = this.accMdtInfo.Terms_And_Condition__c;
                    this.companyName = this.accMdtInfo.Name__c;
                }
                ////console.log(this.msgOnInv);
                this.spinnerFlag = true;
            })
            .catch((error) => {
                ////console.log("###Error : " + error.body.message);
            });


            var tempInvItem = {
                serviceDate : null,
                pdtId : null,
                isKnownPdt : true,
                pdtDraftName: null,
                hsn : null,
                description : null,
                qty : null,
                rate : null,
                amt : null,
                tax : null,
                taxLabel : null,
                taxId : null,
                key: 1,
                taxAmt: null,
                amtWithTax: null
            }
            this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
            tempInvItem.key = 2;
            this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
            ////console.log('invoiceItemList.length = '+this.invoiceItemList.length);
            
            this.ready = true;
        }else{
                emailViewCount({invId: this.recordId}).then((result) => {
                    this.emailViewData = result;
                    ////console.log(result);
                }).catch((error) => {
                    ////console.log("###Error : " + error.body.message);
                });
                ////console.log('Inside the else');
                getInvoiceFormData(
                        {invId: this.recordId}
                    )
                    .then((result) => {
                        // //console.log("Inside the getInvoiceFormData");
                        // //console.log(result);
                        let parsedResultant = JSON.parse(result);
                        ////console.log("parsedResultant.invWrapObj ",parsedResultant.invWrapObj);
                        this.invNumber = parsedResultant.invWrapObj.name;
                        this.parentAccountSelectedRecord.id = parsedResultant.invWrapObj.accId;
                        this.parentContactSelectedRecord.id = parsedResultant.invWrapObj.conId;
                        //this.parentContactSelectedRecord.mainField = parsedResultant.invWrapObj.conName;
                        this.primaryContactEmail = parsedResultant.invWrapObj.primaryConEmailAddresses;
                        this.ccEmailAddressesStr = parsedResultant.invWrapObj.ccEmailAddresses;
                        this.bccEmailAddressesStr = parsedResultant.invWrapObj.bccEmailAddresses;

                        ////console.log('1.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        let tempCCStr = this.ccEmailAddressesStr ? this.ccEmailAddressesStr.replace(' ','') : this.ccEmailAddressesStr;
                        this.ccListLength = tempCCStr ? JSON.parse(JSON.stringify(tempCCStr.split(','))).length : 0;


                        let tempBCCStr = this.bccEmailAddressesStr ? this.bccEmailAddressesStr.replace(' ','') : this.bccEmailAddressesStr;
                        this.bccListLength = tempBCCStr ? JSON.parse(JSON.stringify(tempBCCStr.split(','))).length : 0;

                        ////console.log('2.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.billingAddress = parsedResultant.invWrapObj.billingAddress;
                        this.chosenTerm = parsedResultant.invWrapObj.term;
                        this.chosenTermLabel = parsedResultant.invWrapObj.termLabel;
                        this.invoiceDate = parsedResultant.invWrapObj.invoiceDate;
                        this.dueDate = parsedResultant.invWrapObj.dueDate;
                        this.selectedCountry = parsedResultant.invWrapObj.placeOfSupply;
                        this.authroizedSignature = parsedResultant.invWrapObj.authSign;
                        this.invoiceType = parsedResultant.invWrapObj.invoiceType;
                        this.invoiceNameType = parsedResultant.invWrapObj.invoiceNameType;
                        ////console.log('3.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.chosenParentTaxOption = parsedResultant.invWrapObj.parentTaxSelectedOption;
                        ////console.log('4.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.invoiceItemList = parsedResultant.invWrapObj.invoiceItemList;
                        ////console.log('5.this.invoiceItemList.length = '+this.invoiceItemList.length);
                        this.msgOnInv = parsedResultant.invWrapObj.msgOnInv;
                        this.termsAndCond = parsedResultant.invWrapObj.termsAndCond;
                        //this.currencyInWords = parsedResultant.invWrapObj.amtInWords;
                        ////console.log('currencyInWords = '+this.currencyInWords);
                        this.msgOnStmt = parsedResultant.invWrapObj.msgOnStmt;
                        this.paidAmount = parsedResultant.invWrapObj.paidAmount;

                        //this.currencyCode = parsedResultant.invWrapObj.currencyCode;
                        if(parsedResultant.invWrapObj.currencyCode){
                            const myArray = parsedResultant.invWrapObj.currencyCode.split("-");
                            this.currencyCode = myArray[0];
                            this.currencyCodeName = myArray[1];
                        }
                        
                        this.companyName = parsedResultant.invWrapObj.companyName;

                        this.formDisableFlag = parsedResultant.invWrapObj.invStatus == 'Draft' ? false : true;
                        ////console.log('this.msgOnStmt = '+this.msgOnStmt);
                        /*this.taxVal = parsedResultant.invWrapObj.totalTaxAmt;
                        this.calculatedSubTotal = parsedResultant.invWrapObj.subTotal;
                        this.grandTotal = parsedResultant.invWrapObj.total;
                        this.grandTotal = parsedResultant.invWrapObj.balanceDue;*/

                        //this.fetchTaxOptions();
                        //this.reCalculateSubTaxInfoMap(false);
                        this.spinnerFlag = true;
                        if(this.chosenParentTaxOption === 'Out of scope of Tax') {
                            this.hideSubTaxesSection = true;
                            if(this.recordId && !this.isExecutedOnce && this.invoiceItemList.length > 0){
                                ////console.log('Invoice id not null cond in fetchTaxOptions');
                                //this.isExecutedOnce = true;
                                this.reCalculateSubTaxInfoMap(true);
                            }
                        }
                    })
                    .catch((error) => {
                        ////console.log("###Error : " + error.body.message);
                    });
        }
       
       
        /*setTimeout(() => {
            this.ready = true;
        }, 5000);*/
    }

    renderedCallback()    {  
      ////console.log('This is From child component rendered callback'); 
      if(this.isExecutedOnce) this.ready = true;
      ////console.log('this.ready = '+this.ready);
   }

    
    @track index = 0;

    @track row;
    @track targetIndex;
    @track fromIndex;
    start(event){
        ////console.log('Inside the start');
        ////console.log(event);
        this.row = event.target; 
        ////console.log('this.row = ',this.row);
    }
    over(event){
        ////console.log('Inside the over');
        event.preventDefault();
        var children = Array.from(event.target.parentNode.parentNode.children);
        ////console.log('children ',children);
        
        this.targetIndex = children.indexOf(event.target.parentNode);
        this.fromIndex = children.indexOf(this.row);
        ////console.log('this.targetIndex ',this.targetIndex);
        ////console.log('this.fromIndex ',this.fromIndex);
        /*if(children.indexOf(event.target.parentNode)>children.indexOf(this.row)){
            ////console.log('Inside the if cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.after(this.row);
        } else{
            ////console.log('Inside the else cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.before(this.row);
        }*/
    }

    newDrop(event){
        ////console.log('Inside the newDrop');
        ////console.log('this.targetIndex ',this.targetIndex);
        ////console.log('this.fromIndex ',this.fromIndex);
        /*var tempVar = this.invoiceItemList[this.fromIndex];
        this.invoiceItemList[this.fromIndex] = this.invoiceItemList[this.targetIndex];
        this.invoiceItemList[this.targetIndex] = tempVar;
        ////console.log('this.invoiceItemList['+this.fromIndex+'] ',this.invoiceItemList[this.fromIndex]);
        ////console.log('this.invoiceItemList['+this.targetIndex+'] ',this.invoiceItemList[this.targetIndex]);*/


        /*if(this.targetIndex>this.fromIndex){
            ////console.log('Inside the if cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.insertAfter(this.row);
            event.target.parentNode.after(this.row);
        } else{
            ////console.log('Inside the else cond');
            ////console.log(event.target.parentNode);
            //event.target.parentNode.insertBefore(this.row);
            event.target.parentNode.before(this.row);
        }*/
        //['css', 'js', 'ts']
        const fromIndex = this.fromIndex;
        const toIndex = this.targetIndex;
        const element = this.invoiceItemList.splice(fromIndex, 1)[0];
        ////console.log(element); // ['css']
        this.invoiceItemList.splice(toIndex, 0, element);
        ////console.log(this.invoiceItemList); // 👉️ ['js', 'ts', 'css']
        var tempKey = 1;
        for(let i = 0; i < this.invoiceItemList.length; i++) {
            this.invoiceItemList[i].key = tempKey;
            tempKey++;
        }
    }

    DragStart(event) {
        ////console.log("On DragStart");
        this.dragStart = event.target.title;
        event.target.classList.add("drag");
    }

    DragOver(event) {
        ////console.log("On DragOver");
        ////console.log(event);
        event.preventDefault();
        //return false;
    }

    Drop(event) {
        ////console.log("On Drop");
        ////console.log(event);
        event.stopPropagation();
        const DragValName = this.dragStart;
        const DropValName = event.target.title;
        if (DragValName === DropValName) {
        return false;
        }
        const index = DropValName;
        const currentIndex = DragValName;
        const newIndex = DropValName;
        Array.prototype.move = function (from, to) {
        this.splice(to, 0, this.splice(from, 1)[0]);
        };
        this.invoiceItemList.move(currentIndex, newIndex);
    }

    handleServiceDateChange(event){
        this.serviceDate = event.target.value;
    }


    handlePdtChange(event){
        ////console.log("Inside the handlePdtChange");
        ////console.log(event);
        this.pdtId = event.target.value;
        this.pdtDraftName = null;
        if(this.pdtId == '_new_'){
            ////console.log("Inside the if cond");
            this.hideInputForPdtSerCurrentRow = false;
            this.isKnownPdt = false;
        }else{
            this.hideInputForPdtSerCurrentRow = true;
            this.isKnownPdt = true;
        }
        ////console.log("this.isKnownPdt = "+this.isKnownPdt);
    }
    handlePdtDraftChange(event){
        ////console.log("Inside the handlePdtChange");
        this.pdtDraftName = event.target.value;
    }
    /*currentPdtChangeOnBlur(){
        ////console.log("Inside the currentPdtChangeOnBlur");
        ////console.log(event);
    }*/
    handleHsnChange(event){
        this.hsn = event.target.value;
    }
    handleDescChange(event){
        this.description = event.target.value;
    }
    handleQtyChange(event){
        this.qty = event.target.value;
        if(this.rate) this.amt = (this.qty * this.rate).toFixed(2);
    }
    handleRateChange(event){
        this.rate = event.target.value;
        if(this.qty) this.amt = (this.qty * this.rate).toFixed(2);
    }
    handleAmtChange(event){
        this.amt = event.target.value;
    }
    handleTaxChange(event){
        ////console.log("Inside the handleTaxChange");
        ////console.log(event);
        this.tax = event.target.value;
        ////console.log("tax = "+this.tax);
        this.currentSelectedTaxLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        ////console.log("selectedLabel = "+this.currentSelectedTaxLabel);
        ////console.log("subTaxWholeMap.size = "+this.subTaxWholeMap.size);
        this.taxId = this.subTaxWholeMap.get(this.currentSelectedTaxLabel);
        ////console.log("taxId = "+this.taxId);
        //this.resetChildTaxMap();
    }
    

    updateExistingChildTaxInfoMap(event){
        // ////console.log("Inside the updateExistingChildTaxInfoMap");
        // ////console.log("event ",event);
        ////console.log(this.fetchTaxOptions);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("label ",event.target.dataset.label);
        var previousRowTaxLabel = null;
        var currentRowTaxLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        ////console.log("currentRowTaxLabel = "+currentRowTaxLabel);


        let i = event.target.dataset.index;
        if(this.invoiceItemList[i].tax){
            //previous tax info NA cond
            previousRowTaxLabel = (this.invoiceItemList[i].tax).replace('%','');
            ////console.log("previousRowTaxLabel = "+previousRowTaxLabel);
        }
        this.invoiceItemList[i].tax = event.detail.value;
        this.invoiceItemList[i].taxLabel = currentRowTaxLabel;
        this.invoiceItemList[i].taxId = this.subTaxWholeMap.get(currentRowTaxLabel);
        if(this.invoiceItemList[i].tax){ //this.invoiceItemList[i].amt &&
            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
        }
       // ////console.log('Changed tax value = '+this.invoiceItemList[i].tax);

        this.reCalculateSubTaxInfoMap(false);
    }

    onExistingPdtOptionChange(event){
        ////console.log("Inside the onExistingPdtOptionChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        if(event.target.value == '_new_'){
            ////console.log("Inside the if cond");
            this.invoiceItemList[i].isKnownPdt = false;
        }else{
            this.invoiceItemList[i].isKnownPdt = true;
            this.invoiceItemList[i].pdtDraftName = null;
        }
        this.invoiceItemList[i].pdtId = event.target.value;
    }

    onExistingPdtNameChange(event){
        ////console.log("Inside the onExistingPdtNameChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        this.invoiceItemList[i].pdtDraftName = event.target.value;
    }
 
    onExistingPdtQtyChange(event){
        ////console.log("Inside the onExistingPdtQtyChange");
        ////console.log(JSON.stringify(this.invoiceItemList));
        ////console.log("this.invoiceItemList.length "+ this.invoiceItemList.length);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);
        ////console.log("event.index New = ",event.currentTarget.dataset.index);
        ////console.log("event.value New = ",event.currentTarget.value);

        let i = event.target.dataset.index;
        this.invoiceItemList[i].qty = event.target.value == '' ? null : event.target.value;
        var tempRate = this.invoiceItemList[i].rate ? this.invoiceItemList[i].rate : 0;
        if(tempRate) { 
            var tempQty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
            this.invoiceItemList[i].amt = (tempQty * tempRate).toFixed(2);
            ////console.log('amt: ',this.invoiceItemList[i].amt);

            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'  || !this.invoiceItemList[i].tax || this.invoiceItemList[i].tax == ''){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
            this.reCalculateSubTaxInfoMap(false);
        }
    }

    onExistingPdtRateChange(event){
        ////console.log("Inside the onExistingPdtRateChange");
        ////console.log("this.invoiceItemList.length = "+this.invoiceItemList.length);
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log('Inside the IF cond');
        this.invoiceItemList[i].rate = event.target.value == '' ? null : event.target.value;

        //this.invoiceItemList[i].qty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
        var tempQty = this.invoiceItemList[i].qty ? this.invoiceItemList[i].qty : 0;
        ////console.log('tax: ',this.invoiceItemList[i].tax);
        if(tempQty) { // && this.invoiceItemList[i].tax
            var tempRate = this.invoiceItemList[i].rate ? this.invoiceItemList[i].rate : 0;
            ////console.log('Inside the 2nd IF cond');
            this.invoiceItemList[i].amt = (tempQty * tempRate).toFixed(2);
            ////console.log('amt: ',this.invoiceItemList[i].amt);
            var taxFloat = 0;
            var calTaxVal = 0;
            var amtWithTaxVal = 0;
            if(this.chosenParentTaxOption === 'Out of scope of Tax' || !this.invoiceItemList[i].tax || this.invoiceItemList[i].tax == ''){
                calTaxVal = 0;
                amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }else{
                ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
            }
            ////console.log("calTaxVal ==> "+calTaxVal);
            ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
            this.invoiceItemList[i].taxAmt = calTaxVal;
            this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
            this.reCalculateSubTaxInfoMap(false);
        }
    }



    onExistingHsnChange(event){
        ////console.log("Inside the onExistingHsnChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log("Before: ==> hsn:"+this.invoiceItemList[i].hsn+'index = '+i);
        this.invoiceItemList[i].hsn = event.target.value;
        ////console.log("After: ==> hsn:"+this.invoiceItemList[i].hsn);
    }


    onExistingServiceDateChange(event){
        ////console.log("Inside the onExistingServiceDateChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log("Before: ==> serviceDate:"+this.invoiceItemList[i].serviceDate+'index = '+i);
        this.invoiceItemList[i].serviceDate = event.target.value;
        ////console.log("After: ==> serviceDate:"+this.invoiceItemList[i].serviceDate);
    }


    onExistingDescChange(event){
        ////console.log("Inside the onExistingDescChange");
        ////console.log("event ",event);
        ////console.log("event.index",event.target.dataset.index);
        ////console.log("event.value ",event.target.value);

        let i = event.target.dataset.index;
        ////console.log("Before: ==> description:"+this.invoiceItemList[i].description+'index = '+i);
        this.invoiceItemList[i].description = event.target.value;
        ////console.log("After: ==> description:"+this.invoiceItemList[i].description);
    }

    reCalculateSubTaxInfoMap(isFirstExecution){
        ////console.log("Inside the reCalculateSubTaxInfoMap");
        ////console.log('isFirstExecution = '+isFirstExecution);
        ////console.log('this.invoiceItemList.length = ',this.invoiceItemList.length);
        ////console.log('this.subTaxLabelMap.size = ',this.subTaxLabelMap.size);
        let invMap = new Map();
        this.finalSubTaxesInfoMap = new Map();
        this.invoiceItemList.forEach(element => {
            ////console.log("element.tax = "+element.tax);
            if(element.tax){
                var mapRes = this.subTaxLabelMap.get(element.tax);
                var tempTaxNameVal = mapRes ? mapRes.Name : null;
                ////console.log("tempTaxNameVal = ",tempTaxNameVal);
                let tempAmt = parseFloat(invMap.get(tempTaxNameVal));
                if (!tempAmt) tempAmt = 0;
                invMap.set(tempTaxNameVal,tempAmt+ (element.amt ? parseFloat(element.amt) : 0));
            }
        });
        ////console.log("map size = "+invMap.size);

        if(invMap.size <= 0){
            this.finalSubTaxesInfoJson = [];
        }
        const tempMap = new Map(Object.entries(this.allChildTaxInfoResp.data));
        invMap.forEach((invValues,invKeys) => {
            ////console.log("tempMap.keys = "+invKeys);
            var totalAmt = invMap.get(invKeys);
            ////console.log('totalAmt = '+totalAmt);
            tempMap.forEach((values,keys) => {
                ////console.log("tempMap.keys = "+keys);
                if(invKeys === keys){
                    ////console.log("MATCH FOUND = "+keys);
                    for (let i=0; i < values.length; i++){
                        var label = values[i].Name+' @ '+values[i].Tax_Percentage__c+'% on '+ totalAmt;
                        ////console.log("label ==> "+label);
                        ////console.log("values[i].Tax_Percentage__c = "+values[i].Tax_Percentage__c);
                        var calculatedVal = parseFloat(totalAmt) * (values[i].Tax_Percentage__c / 100);
                        calculatedVal = (Math.round(calculatedVal * 100) / 100).toFixed(2);
                        ////console.log("calculatedVal ==> "+calculatedVal);
                        var tempList = [];
                        let subTaxMapKey = values[i].Name+' @ '+values[i].Tax_Percentage__c+'%';
                        ////console.log("subTaxMapKey ==> "+subTaxMapKey);
                        const subTaxItem = {"Id":label ,"Label":label, "Value":calculatedVal};
                        tempList.push(subTaxItem);
                        this.finalSubTaxesInfoMap.set(subTaxMapKey, tempList);
                    }
                    ////console.log('this.finalSubTaxesInfoMap = '+this.finalSubTaxesInfoMap.size);
                    var newInt=0;
                    this.finalSubTaxesInfoJson = [];
                    this.finalSubTaxesInfoMap.forEach((newValues,newKeys) => {
                        this.finalSubTaxesInfoJson.push(newValues[newInt]);
                    });
                    // ////console.log('this.finalSubTaxesInfoJson = '+this.finalSubTaxesInfoJson.length);
                    // ////console.log('this.finalSubTaxesInfoJson = '+this.finalSubTaxesInfoJson);
                }
            });
        });
        this.calculateSubTotal(isFirstExecution);
    }

    updateRecentChildTaxInfoMap(){
        ////console.log("Inside the updateRecentChildTaxInfoMap");
        ////console.log("selectedLabel = "+this.currentSelectedTaxLabel);
        if(this.invoiceItemList.length <= 0 ){
            return;
        }
        
        // this.prepareInvLabelMap();
        let invMap = new Map();
        this.invoiceItemList.forEach(element => {
            ////console.log("element.tax = "+element.tax);
            ////console.log("Inside the for loop");
            if(element.tax){
                var tempTaxNameVal = this.subTaxLabelMap.get(element.tax).Name;
                ////console.log("tempTaxNameVal = ",tempTaxNameVal);
                let tempAmt = parseFloat(invMap.get(tempTaxNameVal));
                if (!tempAmt) tempAmt = 0;
                invMap.set(tempTaxNameVal,tempAmt+parseFloat(element.amt));
            }
        });
        this.reCalculateSubTaxInfoMap(false);
    }

    

    fetchChildTaxOptions(parentTaxVar){
        ////console.log("Inside the result of fetchChildTaxOptions");
        getChildTaxOptions({
        parentTaxName: parentTaxVar
        })
        .then((result) => {
            ////console.log("Inside the result of getChildTaxOptions");
            ////console.log(result.data);
        })
        .catch((error) => {
            ////console.log("###Error : " + error.body.message);
        });
    }


    get disableAddRowButton(){
        let disableCondVal = !(this.serviceDate && this.hsn && this.description && this.qty && (this.qty > 0)
         && this.rate && (this.rate > 0) && this.amt
         && (this.pdtId && (this.isKnownPdt == true || (this.isKnownPdt == false && this.pdtDraftName)))
         && (this.tax || this.hideSubTaxesSection));
        ////console.log("Inside the disableAddRowButton");
        ////console.log(disableCondVal);
        return disableCondVal;
    }

    get disableCalculateSubTotalButton(){
        return (!(this.invoiceItemList.length > 0) || this.formDisableFlag);
    }

    clearAllRows(){
        this.invoiceItemList = [];
        //this.showSubTotalSection = false;
        this.reCalculateSubTaxInfoMap(false);
        //this.showGrandTotalSection = false;
    }

    get showSubTotalSecConditionally(){
        ////console.log('Inside the showSubTotalSecConditionally');
        ////console.log('this.recordId = '+this.recordId);
        ////console.log('this.isExecutedOnce = '+this.isExecutedOnce);
        if(this.recordId && this.isExecutedOnce){
            ////console.log('In IF');
           return true;
        }else if(!this.recordId){
            ////console.log('In ELSE IF');
            return true;
        }else{
            ////console.log('In ELSE');
            return false;
        }
    }

    calculateSubTotal(isFirstExecution){  
        ////console.log('Inside the calculateSubTotal');
        ////console.log('isFirstExecution = '+isFirstExecution);
        ////console.log(this.invoiceItemList.length);
        let tempSubTotalInt = 0;
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            ////console.log("amt "+parseFloat(this.invoiceItemList[i].amt));
            let intVal = this.invoiceItemList[i].amt ? parseFloat(this.invoiceItemList[i].amt) : 0;
            tempSubTotalInt += intVal;
        }
        ////console.log("tempSubTotalInt = "+tempSubTotalInt);
        this.calculatedSubTotal = tempSubTotalInt.toFixed(2);
        ////console.log(this.calculatedSubTotal);
        //this.showSubTotalSection = true;
        //this.calculateGrandTotal();
        ////console.log('isFirstExecution = ',isFirstExecution);
        if(isFirstExecution) {
            ////console.log('Inside the necessary if cond');
            this.isExecutedOnce = true;
        }
    }

    deleteCurrentRow(){
        ////console.log('Inside the deleteCurrentRow');
        this.serviceDate = null;
        this.pdtId = null;
        this.isKnownPdt = false;
        this.pdtDraftName = null;
        this.hsn = null;
        this.description = null;
        this.qty = null;
        this.rate = null;
        this.amt = null;
        this.tax = null;
        this.taxId = null;
        this.currentSelectedTaxLabel = null;
        this.hideInputForPdtSerCurrentRow = true;
    }

    addNewRow(){
        ////console.log("Inside the addRow");
        ////console.log("Before push length = "+this.invoiceItemList.length);
        //var tempKey = this.invoiceItemList.length > 0 ? (this.invoiceItemList.length - 1) : 0;
        ////console.log('tempKey = '+tempKey);

        var tempInvItem = {
            serviceDate : null,
            pdtId : null,
            isKnownPdt : true,
            pdtDraftName: null,
            hsn : null,
            description : null,
            qty : null,
            rate : null,
            amt : null,
            tax : null,
            taxLabel : null,
            taxId : null,
            taxAmt: null,
            key:null,
            amtWithTax: null
        }


        if(this.invoiceItemList.length > 0) {
            tempInvItem.key = this.invoiceItemList[this.invoiceItemList.length - 1].key + 1;
        } else {
            tempInvItem.key = 1;
        }

        this.invoiceItemList.push(JSON.parse(JSON.stringify(tempInvItem)));
        ////console.log("After push length = "+this.invoiceItemList.length);

    }

    addRow(){
        ////console.log("Inside the addRow");
        ////console.log("Before push length = "+this.invoiceItemList.length);
        ////console.log("isKnownPdt = "+this.isKnownPdt);
        ////console.log("showSubTotalSection = "+this.showSubTotalSection);


        var taxFloat = 0;
        var calTaxVal = 0;
        var amtWithTaxVal = 0;

        if(this.chosenParentTaxOption === 'Out of scope of Tax'){
            calTaxVal = 0;
            amtWithTaxVal = parseFloat(this.amt);
        }else{
            ////console.log(this.tax.replace('%',''));
            taxFloat = this.tax ? parseFloat(this.tax.replace('%','')) : 0;
            calTaxVal = this.amt ? this.amt * (taxFloat / 100) : 0;
            calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
            amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.amt);
            if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = this.amt ? parseFloat(this.amt) : 0;
        }

        ////console.log("calTaxVal ==> "+calTaxVal);
        ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);

        var i = this.index;
        this.invItem = {
            serviceDate : this.serviceDate,
            pdtId : this.pdtId,
            isKnownPdt : this.isKnownPdt,
            pdtDraftName: this.pdtDraftName,
            hsn : this.hsn,
            description : this.description,
            qty : this.qty,
            rate : this.rate,
            amt : this.amt,
            tax : this.tax,
            taxLabel : this.currentSelectedTaxLabel,
            taxId : this.taxId,
            taxAmt: calTaxVal,
            key:i,
            amtWithTax: amtWithTaxVal
        }
        
        ////console.log('this.serviceDate = '+this.serviceDate+' this.invItem.isKnownPdt = '+this.invItem.isKnownPdt);
        this.invoiceItemList.push(JSON.parse(JSON.stringify(this.invItem)));
        ////console.log("After push length = "+this.invoiceItemList.length);
        ////console.log('1st ',this.invoiceItemList[0].isKnownPdt);
        ////console.log('Last ',this.invoiceItemList[(this.invoiceItemList.length-1)].serviceDate);

        /*if(this.showSubTotalSection){
            ////console.log("Inside the expected if cond");
            this.calculateSubTotal(false);
        }*/
        this.calculateSubTotal(false);

        ////console.log("before calling updateRecentChildTaxInfoMap");
        if(this.chosenParentTaxOption !== 'Out of scope of Tax') this.updateRecentChildTaxInfoMap();

        this.serviceDate = null;
        this.pdtId = null;
        this.isKnownPdt = false;
        this.pdtDraftName = null;
        this.hsn = null;
        this.description = null;
        this.qty = null;
        this.rate = null;
        this.amt = null;
        this.tax = null;
        this.taxId = null;
        this.currentSelectedTaxLabel = null;
        this.hideInputForPdtSerCurrentRow = true;
        this.index++;
    }

    removeRow(event){
        ////console.log("Inside removeRow");
        ////console.log("Before this.invoiceItemList.length = "+this.invoiceItemList.length);
        ////console.log("dataset.id = "+event.target.dataset.id);
        ////console.log("dataset.label = "+event.target.dataset.label);
        ////console.log("dataset.index = "+event.target.dataset.index);
        /*var tempIndex = parseInt(event.target.dataset.index)+1;
        ////console.log("tempIndex = "+tempIndex);*/
        if(this.invoiceItemList.length>1) {
            this.invoiceItemList.splice(event.target.dataset.index, 1);
            ////console.log("After this.invoiceItemList.length = "+this.invoiceItemList.length);
            /*if(this.showSubTotalSection){
                this.calculateSubTotal(false);
            }*/
            this.calculateSubTotal(false);
        }
        else if(this.invoiceItemList.length==1) {
            this.invoiceItemList=[];
            //this.showSubTotalSection = false;
        }
        
        this.reCalculateSubTaxInfoMap(false);
    } 

    removeRowNew(event) {
        ////console.log('Inside the removeRowNew');
        ////console.log(event);
        let toBeDeletedRowKey = event.target.dataset.key;
        ////console.log('Before invoiceItemList length = '+this.invoiceItemList.length);

        let invoiceItemListTemp = [];
        for(let i = 0; i < this.invoiceItemList.length; i++) {
            let tempRecord = Object.assign({}, this.invoiceItemList[i]); //cloning object
            ////console.log(tempRecord);
            ////console.log('tempRecord.key = ',tempRecord.key+' & toBeDeletedRowKey = ',toBeDeletedRowKey);
            ////console.log('typeof tempRecord.key',typeof tempRecord.key);
            ////console.log('typeof toBeDeletedRowKey',typeof toBeDeletedRowKey);
            if(tempRecord.key != toBeDeletedRowKey) {
                ////console.log('Inside the push logic ');
                invoiceItemListTemp.push(tempRecord);
            }else{
                ////console.log('Inside the else logic ');
            }
        }
        ////console.log('invoiceItemListTemp length = '+invoiceItemListTemp.length);
        for(let i = 0; i < invoiceItemListTemp.length; i++) {
            invoiceItemListTemp[i].key = i + 1;
        }

        this.invoiceItemList = invoiceItemListTemp;
        this.reCalculateSubTaxInfoMap(false);
        ////console.log('After invoiceItemList length = '+this.invoiceItemList.length);
        ////console.log('End of Method');
    }
    


    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountInfo;

    @wire(getPicklistValues,
        {
            recordTypeId: '$accountInfo.data.defaultRecordTypeId',
            fieldApiName: BillingCountryCode
        }
    )
    listOfCountries;

    
    handleCountryChange(event){
        ////console.log(this.listOfCountries.data);
        ////console.log(event);
        ////console.log('Inside the handleCountryChange');
        this.selectedCountry = event.target.value;
        ////console.log('selectedCountry = '+this.selectedCountry);
    }

    handleAuthChange(event){
        ////console.log(this.listOfCountries.data);
        ////console.log(event);
        ////console.log('Inside the handleCountryChange');
        this.authroizedSignature = event.target.value;
       // //console.log('authroizedSignature = '+this.authroizedSignature);
    }
    

    handleValueSelectedOnAccount(event) {
        // //console.log("Inside the handleValueSelectedOnAccount");
        // //console.log(event);
        ////console.log(JSON.parse(JSON.stringify(event.detail)));
        this.parentAccountSelectedRecord = event.detail;
        this.billingAddress = this.parentAccountSelectedRecord.subField;
        //this.currencyCode = this.parentAccountSelectedRecord.additionalField;
        if(this.parentAccountSelectedRecord.additionalField){
            const myArray = this.parentAccountSelectedRecord.additionalField.split("-");
            this.currencyCode = myArray[0];
            this.currencyCodeName = myArray[1];
        }
        ////console.log(this.parentAccountSelectedRecord);
        ////console.log("this.parentAccountSelectedRecord.id = "+this.parentAccountSelectedRecord.id);
        ////console.log(this.parentAccountSelectedRecord.mainField);
        ////console.log(this.parentAccountSelectedRecord.subField);
    }
    handleAccValRemoval(event){
        ////console.log("Inside the handleAccValRemoval");
        ////console.log(event);
        ////console.log(event.detail);
        //this.parentAccountSelectedRecord = event.detail;
        this.parentAccountSelectedRecord.mainField = null;
        this.parentAccountSelectedRecord.subField = null;
        this.parentAccountSelectedRecord.id = null;
        this.parentAccountSelectedRecord.additionalField = null;
        ////console.log("this.parentContactSelectedRecord",JSON.parse(JSON.stringify(this.parentContactSelectedRecord)));
        //this.parentContactSelectedRecord = null;
        this.parentContactSelectedRecord.mainField = null;
        this.parentContactSelectedRecord.subField = null;
        this.parentContactSelectedRecord.id = null;
        // this.primaryContactEmail = null;
        this.currencyCode = null;
    }

    handleValueSelectedOnContact(event) {
        ////console.log("Inside the handleValueSelectedOnContact");
        ////console.log(event);
        this.parentContactSelectedRecord = event.detail;
        ////console.log("this.parentContactSelectedRecord",JSON.parse(JSON.stringify(this.parentContactSelectedRecord)));
        ////console.log(this.parentContactSelectedRecord.id);
        ////console.log(this.parentContactSelectedRecord.mainField);
        ////console.log("this.parentContactSelectedRecord.subField = "+this.parentContactSelectedRecord.subField);
        this.primaryContactEmail = this.parentContactSelectedRecord.subField;
    }
    handleConValRemoval(){
        ////console.log("Inside the handleConValRemoval");
        ////console.log(event);
        //this.parentContactSelectedRecord = event.detail;
        this.parentContactSelectedRecord.mainField = null;
        this.parentContactSelectedRecord.subField = null;
        this.parentContactSelectedRecord.id = null;
        this.primaryContactEmail = null;
    }

    get parentTaxOptions(){
        return [
            { label:"Exclusive of Tax", value:"Exclusive of Tax" },
            { label:"Inclusive of Tax", value:"Inclusive of Tax" },
            { label:"Out of scope of Tax", value:"Out of scope of Tax" }
        ];
    }

    ccBccSecOnClose(){
        ////console.log("Inside the ccBccSecOnClose");
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        this.showCcBccSec = !this.showCcBccSec;
    }

    ccBccSecCancel(){
        ////console.log("Inside the ccBccSecCancel");
        this.showCcBccSec = !this.showCcBccSec;
    }

    ccBccSecDone(){
        ////console.log("Inside the ccBccSecDone");
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        if(this.isInputValid()) {
            ////console.log('Inside the isInputValid cond');
            this.ccEmailAddressesStr = this.tempCcEmailAddressesStr;
            this.bccEmailAddressesStr = this.tempBccEmailAddressesStr;
            let tempCCListStr = this.ccEmailAddressesStr ? this.ccEmailAddressesStr.replace(' ','') : null;
            this.ccListLength = tempCCListStr ? JSON.parse(JSON.stringify(tempCCListStr.split(','))).length : 0;
            ////console.log("tempCCListStr = ",tempCCListStr);
            ////console.log("this.ccListLength = ",this.ccListLength);
            let tempBCCListStr = this.bccEmailAddressesStr ? this.bccEmailAddressesStr.replace(' ','') : null;
            this.bccListLength = tempBCCListStr ? JSON.parse(JSON.stringify(tempBCCListStr.split(','))).length : 0;
            ////console.log("tempBCCListStr = ",tempBCCListStr);
            ////console.log("this.bccListLength = ",this.bccListLength);
            ////console.log("ALL THE INPUTS ARE VALID");
            this.showCcBccSec = !this.showCcBccSec;
        }
        
    }

    isInputValid() {
        ////console.log("Inside the isInputValid method");
        let isValid = true;
        ////console.log(this.template);
        let inputFields = this.template.querySelectorAll('.ccBccInputSec');
        ////console.log(inputFields);
        inputFields.forEach(inputField => {
            ////console.log('Inside the foreach ',inputField);
            ////console.log('inputField.checkValidity() = ',inputField.checkValidity());
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    updateContactEmailList(event){
        ////console.log("Inside the updateContactEmailList");
        this.primaryContactEmail = event.target.value;
        ////console.log("this.primaryContactEmail = ",this.primaryContactEmail);
    }
    updateBillingAddress(event){
        ////console.log("Inside the updateBillingAddress");
        ////console.log(event);
        ////console.log(event.target);
        ////console.log(event.target.value);
        //this.parentAccountSelectedRecord.subField = event.target.value;
        this.billingAddress = event.target.value;
    }

    get disableSaveButton(){
        ////console.log("Inside the disableSaveButton");
        let disableFlag = false;
        ////console.log("this.parentAccountSelectedRecord.id = ",this.parentAccountSelectedRecord.id);
        ////console.log("this.parentContactSelectedRecord.id = ",this.parentContactSelectedRecord.id);
        ////console.log("this.primaryContactEmail = ",this.primaryContactEmail);
        ////console.log("this.ccEmailAddressesStr = ",this.ccEmailAddressesStr);
        ////console.log("this.bccEmailAddressesStr = ",this.bccEmailAddressesStr);
        ////console.log("this.parentAccountSelectedRecord.subField = ",this.parentAccountSelectedRecord.subField);
        ////console.log("this.chosenTerm = ",this.chosenTerm); 
        ////console.log("this.invoiceDate = ",this.invoiceDate); 
        ////console.log("this.dueDate = ",this.dueDate); 
        ////console.log("this.selectedCountry = ",this.selectedCountry); 
        ////console.log("this.chosenParentTaxOption = ",this.chosenParentTaxOption); 
        ////console.log("this.invoiceItemList.length = ",this.invoiceItemList.length); 
        ////console.log("this.msgOnInv = ",this.msgOnInv); 
        ////console.log("this.msgOnStmt = ",this.msgOnStmt);
        disableFlag = !(
            (this.parentAccountSelectedRecord.id != null && this.parentAccountSelectedRecord.id != undefined  && this.parentAccountSelectedRecord.id != '') &&
            (this.parentContactSelectedRecord.id != null && this.parentContactSelectedRecord.id != undefined  && this.parentContactSelectedRecord.id != '') &&
            (this.primaryContactEmail != null && this.primaryContactEmail != undefined && this.primaryContactEmail != '') &&
            (this.billingAddress != null && this.billingAddress != undefined && this.billingAddress != '') &&
            (this.chosenTerm != null && this.chosenTerm != undefined && this.chosenTerm != '') &&
            (this.invoiceDate != null && this.invoiceDate != undefined && this.invoiceDate != '') &&
            (this.dueDate != null && this.dueDate != undefined && this.dueDate != '') &&
            (this.selectedCountry != null && this.selectedCountry != undefined && this.selectedCountry != '') &&
            (this.authroizedSignature != null && this.authroizedSignature != undefined && this.authroizedSignature != '') &&
            (this.chosenParentTaxOption != null && this.chosenParentTaxOption != undefined && this.chosenParentTaxOption != '') &&
            (this.invoiceItemList.length != null && this.invoiceItemList.length != undefined && this.invoiceItemList.length > 0) &&
            (this.msgOnInv != null && this.msgOnInv != undefined && this.msgOnInv != '') &&
            (this.termsAndCond != null && this.termsAndCond != undefined && this.termsAndCond != '') &&
            (this.msgOnStmt != null && this.msgOnStmt != undefined && this.msgOnStmt != '')       
            );

        ////console.log(" Before forloop disableFlag = ",disableFlag);

        if(disableFlag) return disableFlag;

        ////console.log("this.invoiceItemList.length = ",this.invoiceItemList.length);
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            ////console.log('this.invoiceItemList[i].serviceDate = '+this.invoiceItemList[i].serviceDate);
            let serviceCond = (this.invoiceItemList[i].serviceDate != null 
                    && this.invoiceItemList[i].serviceDate != undefined && this.invoiceItemList[i].serviceDate != '');
            let pdtIdCond = (this.invoiceItemList[i].pdtId != null 
                    && this.invoiceItemList[i].pdtId != undefined && this.invoiceItemList[i].pdtId != '');
            /*let isKnownPdtCond = (this.invoiceItemList[i].isKnownPdt != null 
                    && this.invoiceItemList[i].isKnownPdt != undefined && this.invoiceItemList[i].isKnownPdt != '');*/
            let pdtDraftNameCond = (this.invoiceItemList[i].isKnownPdt == true ||
                (this.invoiceItemList[i].isKnownPdt == false && 
                    this.invoiceItemList[i].pdtDraftName != null && this.invoiceItemList[i].pdtDraftName != undefined 
                    && this.invoiceItemList[i].pdtDraftName != ''));
            let hsnCond = (this.invoiceItemList[i].hsn != null 
                    && this.invoiceItemList[i].hsn != undefined && this.invoiceItemList[i].hsn != '');
            let descriptionCond = (this.invoiceItemList[i].description != null 
                    && this.invoiceItemList[i].description != undefined && this.invoiceItemList[i].description != '');
            let qtyCond = (this.invoiceItemList[i].qty != null 
                    && this.invoiceItemList[i].qty != undefined && this.invoiceItemList[i].qty != '' 
                    && this.invoiceItemList[i].qty > 0);
            let rateCond = (this.invoiceItemList[i].rate != null 
                    && this.invoiceItemList[i].rate != undefined && this.invoiceItemList[i].rate != '' 
                    && this.invoiceItemList[i].rate > 0);
            let amtCond = (this.invoiceItemList[i].amt != null 
                    && this.invoiceItemList[i].amt != undefined && this.invoiceItemList[i].amt != '' 
                    && this.invoiceItemList[i].amt > 0);
            let taxCond = (this.invoiceItemList[i].tax != null 
                    && this.invoiceItemList[i].tax != undefined && this.invoiceItemList[i].tax != '');
            let taxLabelCond = (this.invoiceItemList[i].taxLabel != null 
                    && this.invoiceItemList[i].taxLabel != undefined && this.invoiceItemList[i].taxLabel != '');
            let taxIdCond = (this.invoiceItemList[i].taxId != null 
                    && this.invoiceItemList[i].taxId != undefined && this.invoiceItemList[i].taxId != '');
            let wholeTaxCond = (this.chosenParentTaxOption === 'Out of scope of Tax' || 
                (this.chosenParentTaxOption !== 'Out of scope of Tax' && taxCond && taxLabelCond && taxIdCond));

            if(disableFlag == false){
                ////console.log("Inside the disableFlag false cond");
                ////console.log('1.serviceDate = '+this.invoiceItemList[i].serviceDate +' cond:'+serviceCond);
                ////console.log('2.pdtId = '+this.invoiceItemList[i].pdtId +' cond:'+pdtIdCond);
                ////console.log('3.isKnownPdt = '+this.invoiceItemList[i].isKnownPdt +' cond:'+isKnownPdtCond);
                ////console.log('3.pdtDraftName = '+this.invoiceItemList[i].pdtDraftName +' cond:'+pdtDraftNameCond);
                ////console.log('4.hsn = '+this.invoiceItemList[i].hsn +' cond:'+hsnCond);
                ////console.log('5.description = '+this.invoiceItemList[i].description +' cond:'+descriptionCond);
                ////console.log('6.qty = '+this.invoiceItemList[i].qty +' cond:'+qtyCond);
                ////console.log('7.rate = '+this.invoiceItemList[i].rate+' cond:'+rateCond);
                ////console.log('8.amt = '+this.invoiceItemList[i].amt+' cond:'+amtCond);
                ////console.log('9.tax = '+this.invoiceItemList[i].tax +' cond:'+taxCond);
                ////console.log('10.taxLabel = '+this.invoiceItemList[i].taxLabel +' cond:'+taxLabelCond);
                ////console.log('11.taxId = '+this.invoiceItemList[i].taxId +' cond:'+taxIdCond);
                ////console.log('12.wholeTaxCond = '+this.invoiceItemList[i].chosenParentTaxOption +' cond:'+wholeTaxCond);

                disableFlag = !(serviceCond && pdtIdCond && pdtDraftNameCond && hsnCond 
                    && descriptionCond && qtyCond && rateCond && amtCond && wholeTaxCond);

            }else{
                ////console.log("Inside the disableFlag true cond");
                return disableFlag
            }
            ////console.log("Inside forloop  disableFlag = ",disableFlag);
        }
        
        ////console.log("OutSide of forloop disableFlag = ",disableFlag);
        return disableFlag;
    }

    saveAndSendAction() {
        this.sendEmailFlag = true;
        //console.log('Inside the saveAndSendAction');
        this.checkboxjournalflag;
        this.saveAction()
            .then(() => {
                //console.log('Inside the saveAndSendAction');
                //return this.createJournalEntry();
            })
            .catch(error => {
                //console.error('Error in saveAction:', error);
                // Handle error (e.g., show a toast message)
            });
    }

    saveAction() {
      //  //console.log("Inside the saveAction");
        return new Promise((resolve, reject) => {
        var taxVal = 0;
            if (this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Exclusive of Tax") {
            ////console.log('Inside the if cond');
                for (let i = 0; i < this.finalSubTaxesInfoJson.length; i++) {
                ////console.log('Inside the for cond');
                taxVal = taxVal + parseFloat(this.finalSubTaxesInfoJson[i].Value);
                ////console.log("taxVal ===> "+taxVal);
            }
        } 
        ////console.log("Before objWrap preparation step");  

        let finalInvItemList = [];
        ////console.log("Before this.invoiceItemList.length = ",this.invoiceItemList.length);
        for (let i = 0; i < this.invoiceItemList.length; i++) {
            var serviceDateCond = (this.invoiceItemList[i].serviceDate != null 
                    && this.invoiceItemList[i].serviceDate != undefined && this.invoiceItemList[i].serviceDate != '');
            var pdtIdCond = (this.invoiceItemList[i].pdtId != null 
                    && this.invoiceItemList[i].pdtId != undefined && this.invoiceItemList[i].pdtId != '');
            var pdtDraftNameCond = (this.invoiceItemList[i].pdtDraftName != null && this.invoiceItemList[i].pdtDraftName != undefined 
                    && this.invoiceItemList[i].pdtDraftName != '');
            var hsnCond = (this.invoiceItemList[i].hsn != null 
                    && this.invoiceItemList[i].hsn != undefined && this.invoiceItemList[i].hsn != '');
            var descriptionCond = (this.invoiceItemList[i].description != null 
                    && this.invoiceItemList[i].description != undefined && this.invoiceItemList[i].description != '');
            var qtyCond = (this.invoiceItemList[i].qty != null 
                    && this.invoiceItemList[i].qty != undefined && this.invoiceItemList[i].qty != '' 
                    && this.invoiceItemList[i].qty > 0);
            var rateCond = (this.invoiceItemList[i].rate != null 
                    && this.invoiceItemList[i].rate != undefined && this.invoiceItemList[i].rate != '' 
                    && this.invoiceItemList[i].rate > 0);
            var taxCond = (this.invoiceItemList[i].tax != null 
                    && this.invoiceItemList[i].tax != undefined && this.invoiceItemList[i].tax != '');

            if(
                (this.chosenParentTaxOption !== "Out of scope of Tax" 
                    && (serviceDateCond || pdtIdCond || pdtDraftNameCond || hsnCond || descriptionCond || qtyCond 
                        || rateCond || taxCond))
                || (this.chosenParentTaxOption === "Out of scope of Tax" 
                    && (serviceDateCond || pdtIdCond || pdtDraftNameCond || hsnCond || descriptionCond || qtyCond 
                        || rateCond))){
                        //Having any one of the field value, so have to be saved
                        ////console.log('Inside the if cond - i '+i);
                        finalInvItemList.push(this.invoiceItemList[i]);
                    }
            else{
                ////console.log('Inside the else cond - i '+i);
                //Not having any one of the field value, so have to be removed from invoiceItemList
                //this.invoiceItemList.splice(i, 1);
            }
        }
        ////console.log("After this.invoiceItemList.length = ",this.invoiceItemList.length);


        var invStatusVar = null;
        if(!this.recordId){
            invStatusVar = 'Draft';
        }
        
        // //console.log("this.accMdtInfo = "+this.accMdtInfo);
        // //console.log('mdt Name = '+this.accMdtInfo.Name__c);

        ////console.log("this.msgOnStmt = "+this.msgOnStmt);
        var invWrapObj = {
            invId:this.recordId,
            invNumber: this.invNumber,
            accId: this.parentAccountSelectedRecord.id,
            conId: this.parentContactSelectedRecord.id,
            primaryConEmailAddresses: this.primaryContactEmail,
            ccEmailAddresses: this.ccEmailAddressesStr,
            bccEmailAddresses: this.bccEmailAddressesStr,
            billingAddress: this.billingAddress,
            term: this.chosenTerm,
            termLabel: this.chosenTermLabel,
            invoiceDate: this.invoiceDate,
            dueDate: this.dueDate,
            placeOfSupply: this.selectedCountry,
            invoiceType: this.invoiceType,
            invoiceNameType: this.invoiceNameType,
            authSign: this.authroizedSignature,
            parentTaxSelectedOption: this.chosenParentTaxOption,
            invoiceItemList: finalInvItemList, //this.invoiceItemList,
            msgOnInv: this.msgOnInv,
            termsAndCond: this.termsAndCond,
            msgOnStmt: this.msgOnStmt,
            subTotal: this.calculatedSubTotal,
            total: this.grandTotal,
            balanceDue: this.paidAmount,
            totalTaxAmt: taxVal,
            //name: 'SampleInv - '+ this.invoiceDate,
            invStatus: invStatusVar,
            companyName: this.companyName,
            currencyCode: this.currencyCode,
            currencyCodeName: this.currencyCodeName
        }
        

        console.log('invWrapObj = ',JSON.stringify(invWrapObj));

        saveInvoiceRecord({
            invWrap: JSON.stringify(invWrapObj),
            sendEmailFlag: this.sendEmailFlag,
            checkboxjournalflag: this.checkboxjournalflag
        })
        .then((result) => {
            ////console.log("Inside the result of saveInvoiceRecord");
            console.log(result);
            let parsedResultant = JSON.parse(result);
            console.log("parsedResultant ",parsedResultant);
            ////console.log(typeof parsedResultant.successFlag);
            //console.log(typeof parsedResultant.invoiceId);
            console.log(parsedResultant.invoiceId);
            this.invoicerecordId =parsedResultant.invoiceId;
            console.log('invoicerecordId---->',this.invoicerecordId);
            if(!parsedResultant.successFlag){
                this.errorMessage = parsedResultant.errorMessage;
                /*LightningPrompt.open({
                    message: this.errorMessage,
                    label: 'Please fill the missing required info',
                }).then((result) => {
                    ////console.log('Result: '+ result);
                });*/

                var tempMsg = this.errorMessage;
                const toastEvent = new ShowToastEvent({
                    title:'Failure!',
                    message:tempMsg,
                    variant:'error'
                    //mode:'sticky'
                });

                this.dispatchEvent(toastEvent);
                reject(this.errorMessage);

            }else if(parsedResultant.successFlag && parsedResultant.invoiceId){
                //console.log('Record created successfully:', JSON.stringify(parsedResultant.invoiceId));
                var tempMsg = this.recordId ? 'Record updated successfully' : 'Record created successfully';
                const toastEvent = new ShowToastEvent({
                    title:'Success!',
                    message:tempMsg,
                    variant:'success'
                });
                this.dispatchEvent(toastEvent);

                ////console.log('Inside the elseIf cond');
                //Start Navigation
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: parsedResultant.invoiceId,
                        objectApiName: 'Invoice__c',
                        actionName: 'view'
                    },
                });
                resolve(parsedResultant.invoiceId);
                //End Navigation
            }
        })
        .catch((error) => {
            ////console.log("###Error : " + error.body.message);
        });
        this.sendEmailFlag = false;
        // console.log('podaaaa');
        
        // saveInvoiceRecord({ invWrap: JSON.stringify(this.invWrapObj), sendEmailFlag: this.sendEmailFlag })
        //     .then(result => {
        //         let parsedResultant = JSON.parse(result);
        //         console.log("parsedResultant ",parsedResultant);
        //         ////console.log(typeof parsedResultant.successFlag);
        //         //console.log(typeof parsedResultant.invoiceId);
        //         console.log(parsedResultant.invoiceId);
        //         this.invoicerecordId =parsedResultant.invoiceId;
        //         console.log('Invoice saved successfully:', result);
        //         resolve();
        //     })
        //     .catch(error => {
        //         console.error('Error saving invoice:', error);
        //         reject(error);
        //     });

        
        });
    }

    validateInvoice() {
        console.log('Inside the validateInvoice');
        console.log('this.invoicerecordId = ',this.invoicerecordId);   
        // this.invoicerecordIdValid = this.invoicerecordId;
        
        validateInvoiceRecord({ invoiceId: String(this.invoicerecordId) })
            .then(response => {
                console.log('Validation Successful:', response);
                
                this.showToast('Validation Successful!', 'Invoice data validated successfully.', 'success');
            })
            .catch(error => {
                this.showToast('Validation Failed!', error.body.message, 'error');
            });
    }

    validateAndSave() {
        console.log('Inside the validateAndSave');
        
        this.saveAction()
            .then((invoiceId) => {
                console.log('abdullah');
                console.log('Result:', invoiceId);
                // this.invoiceIdNew = invoiceId;
                this.validateInvoice();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    clearance() {
        console.log('Inside the clearance');
        console.log('invoicerecordId = ',this.recordId);
        
        clearanceInvoice({ invoiceId: this.recordId })
            .then(response => {
                console.log('Clearance Successful:', response);
                this.showToast('Clearance Successful!', 'Invoice cleared successfully.', 'success');
                location.reload();
            })
            .catch(error => {
                this.showToast('Clearance Failed!', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(toastEvent);
    }

    msgOnStmtOnChange(event){
        ////console.log("Inside the msgOnStmtOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.msgOnStmt = event.target.value;
        ////console.log("this.msgOnStmt = ",this.msgOnStmt);
    }


    msgOnInvOnChange(event){
        ////console.log("Inside the msgOnInvOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.msgOnInv = event.target.value;
        ////console.log("this.msgOnInv = ",this.msgOnInv);
    }


    termsAndCondOnChange(event){
      //  //console.log("Inside the termsAndCondOnChange");
      //  //console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.termsAndCond = event.target.value;
      //  //console.log("this.termsAndCond = ",this.termsAndCond);
    }
  

    emailViewCnt(event){
        
          this.EmailViewCount = event.target.value;
        //  //console.log("this.termsAndCond = ",this.termsAndCond);
      }

    ccOnChange(event){
        ////console.log("Inside the ccOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.tempCcEmailAddressesStr = event.target.value;
        ////console.log("this.tempCcEmailAddressesStr = ",this.tempCcEmailAddressesStr);
    }

    bccOnChange(event){
        ////console.log("Inside the bccOnChange");
        ////console.log(event);
        ////console.log("event.target.value = "+event.target.value);
        this.tempBccEmailAddressesStr = event.target.value;
        ////console.log("this.tempBccEmailAddressesStr = ",this.tempBccEmailAddressesStr);
    }

    ccBccSecOnClick(){
        ////console.log("Inside the ccBccSecOnClick");
        this.showCcBccSec = !this.showCcBccSec;
    }

    insertBefore(newNode, existingNode) {
        ////console.log("Inside the insertBefore");
        existingNode.parentNode.insertBefore(newNode, existingNode.nextSibling);
    }

    handleParentTaxChange(event){
        ////console.log("Inside the handleParentTaxChange method");
        ////console.log("Previous this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        /*if(this.chosenParentTaxOption === "Out of scope of Tax"){ //"Out of scope of Tax" to another tax option change
            this.clearAllRows();
            this.chosenParentTaxOption = event.detail.value;
            return;
        }*/
        this.chosenParentTaxOption = event.detail.value;
        ////console.log("After this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        ////console.log("this.chosenParentTaxOption = "+this.chosenParentTaxOption);
        if(this.chosenParentTaxOption){
            ////console.log("First if cond");
            //this.showGrandTotalSection = true;
            if(this.chosenParentTaxOption === 'Out of scope of Tax'){
                ////console.log("First if cond");
                this.hideSubTaxesSection = true;
                for (let i = 0; i < this.invoiceItemList.length; i++) {
                    this.invoiceItemList[i].taxAmt = 0;
                    this.invoiceItemList[i].amtWithTax = parseFloat(this.invoiceItemList[i].amt);
                }
            }else{
                ////console.log("else cond");
                this.hideSubTaxesSection = false;
                for (let i = 0; i < this.invoiceItemList.length; i++) {
                    this.invoiceItemList[i].taxAmt = 0;
                    this.invoiceItemList[i].amtWithTax = this.invoiceItemList[i].amt;
                    if(this.invoiceItemList[i].amt && this.invoiceItemList[i].tax){
                        var taxFloat = 0;
                        var calTaxVal = 0;
                        var amtWithTaxVal = 0;
                        ////console.log(this.invoiceItemList[i].tax.replace('%',''));
                        taxFloat = parseFloat(this.invoiceItemList[i].tax.replace('%',''));
                        calTaxVal = this.invoiceItemList[i].amt * (taxFloat / 100);
                        calTaxVal = (Math.round(calTaxVal * 100) / 100).toFixed(2);
                        amtWithTaxVal = parseFloat(calTaxVal) + parseFloat(this.invoiceItemList[i].amt);
                        if(this.chosenParentTaxOption === 'Inclusive of Tax') amtWithTaxVal = parseFloat(this.invoiceItemList[i].amt);
                        ////console.log("calTaxVal ==> "+calTaxVal);
                        ////console.log("amtWithTaxVal ==> "+amtWithTaxVal);
                        this.invoiceItemList[i].taxAmt = calTaxVal;
                        this.invoiceItemList[i].amtWithTax = amtWithTaxVal;
                    }
                }
            }
        }
        this.calculateSubTotal(false);
        //this.calculateGrandTotal();
    }

    /*calculateGrandTotal(){
        ////console.log("Inside the calculateGrandTotal method");
        this.grandTotal = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            this.grandTotal = this.calculatedSubTotal;
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            for(let i=0; i<this.finalSubTaxesInfoJson.length; i++){
                ////console.log("Value ===> "+this.finalSubTaxesInfoJson[i].Value);
                this.grandTotal = this.grandTotal + (this.finalSubTaxesInfoJson[i].Value ? parseFloat(this.finalSubTaxesInfoJson[i].Value) : 0);
            }
            this.grandTotal = parseFloat(this.calculatedSubTotal) + this.grandTotal;
            this.grandTotal = (Math.round(this.grandTotal * 100) / 100).toFixed(2);
            ////console.log("this.grandTotal ===> "+this.grandTotal);
        }else{
            //this.showGrandTotalSection = false;
        }
    }*/

    get grandTotal(){
        ////console.log("Inside the grandTotal");
        let gt = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            gt = this.calculatedSubTotal;
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            for(let i=0; i<this.finalSubTaxesInfoJson.length; i++){
                ////console.log("Value ===> "+this.finalSubTaxesInfoJson[i].Value);
                gt = gt + (this.finalSubTaxesInfoJson[i].Value ? parseFloat(this.finalSubTaxesInfoJson[i].Value) : 0);
            }
            gt = parseFloat(this.calculatedSubTotal) + gt;
            gt = (Math.round(gt * 100) / 100).toFixed(2);
            ////console.log("gt ===> "+gt);
        }else{
           gt = null;
        }
        return gt;
    }
    get balanceDue(){
        ////console.log("Inside the grandTotal");
        let gt = 0.00;
        if(this.chosenParentTaxOption === "Inclusive of Tax" || this.chosenParentTaxOption === "Out of scope of Tax"){
            gt = this.calculatedSubTotal;
            ////console.log('this.paidAmount'+this.paidAmount);
            
            gt = gt-(this.paidAmount==undefined ||this.paidAmount==''? 0:this.paidAmount);
            gt = (gt >0 ? gt:0.00);
            gt = (Math.round(gt * 100) / 100).toFixed(2);
        }else if(this.chosenParentTaxOption === "Exclusive of Tax"){
            for(let i=0; i<this.finalSubTaxesInfoJson.length; i++){
                ////console.log("Value ===> "+this.finalSubTaxesInfoJson[i].Value);
                gt = gt + (this.finalSubTaxesInfoJson[i].Value ? parseFloat(this.finalSubTaxesInfoJson[i].Value) : 0);
            }
            gt = parseFloat(this.calculatedSubTotal) + gt;
            ////console.log('this.paidAmount'+this.paidAmount);
            gt = gt-(this.paidAmount==undefined || this.paidAmount=='' ? 0:this.paidAmount);
            gt = (gt >0 ? gt:0.00);
            gt = (Math.round(gt * 100) / 100).toFixed(2);
            
           // //console.log("gt ===> "+gt);
        }else{
           gt = null;
        }
        return gt;
    }

    get termsOptions(){
        return [
            { label:"0", value:"0" },
            { label:"Net 7", value:"7" },
            { label:"Net 15", value:"15" },
            { label:"Net 30", value:"30" },
            { label:"Net 45", value:"45" },
            { label:"Net 60", value:"60" }
        ];
    }

    handleTermsChange(event){
            ////console.log("Inside the handleTermsChange method");
            this.chosenTerm = event.detail.value;
            this.chosenTermLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
            
            if (this.invoiceDate !== null) {
                var data_out = new Date(this.invoiceDate);
                let dateInMS = data_out.setDate(data_out.getDate() + parseInt(this.chosenTerm));
                var data_out_02 = new Date(dateInMS);
                this.dueDate = data_out_02.toISOString().substring(0, 10); //NEW
                //OLD: this.dueDate = data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"});
                //ERRORED: this.dueDate = new Date(new Date().setDate(data_out.getDate() + parseInt(this.chosenTerm))).toISOString().substring(0, 10);
            }


        }

    invoiceDateChange(event){
        ////console.log("Inside the invoiceDateChange method");
        this.invoiceDate = event.target.value;

        if (this.chosenTerm !== null) {
            var data_out = new Date(this.invoiceDate);
            let dateInMS = data_out.setDate(data_out.getDate() + parseInt(this.chosenTerm));
            var data_out_02 = new Date(dateInMS);

            //Sol #1 - with WeekDay value - Fri, Jul 2, 2021
            //this.dueDate = data_out_02.toDateString();

            // Sol #2 - with WeekDay long value - "Friday, Jul 2, 2021"
            ////console.log(data_out_02.toLocaleDateString('en-us', { weekday:"long", year:"numeric", month:"short", day:"numeric"}));

             // Sol #3 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - But onSave throwing error due to invalid format
            ////console.log(data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"}));
            //this.dueDate = data_out_02.toLocaleDateString('en-us', { year:"numeric", month:"short", day:"numeric"});

            // Sol #4 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - errored onSave
            //this.dueDate = new Date(new Date().setDate(data_out.getDate() + parseInt(this.chosenTerm))).toISOString().substring(0, 10);

            // Sol #5 - Expected sol - Jul 2, 2021 - 'MMM D, YYYY' format - success onSave
            this.dueDate = data_out_02.toISOString().substring(0, 10); //NEW

        }

    }

    //Call this method from your .html file
    openVisualForcePage(event) 
    {
        //this.previewPdfFlag = true;
        this.vfPageURLToPreview = '/apex/InvoicePdf?id='+this.recordId;
       // this.vfPageURLToPreview = '/apex/InvoicePdf?id='+this.recordId;
        this.isGreyedOut = true;
        this.popupDivStyle = "position:absolute;height:50%;width:50%;margin-top:-"+window.innerHeight+"px;margin-left:"+(window.innerWidth / 4)+"px;";
        /*const urlWithParameters = '/apex/InvoicePdf?id='+this.recordId;
        ////console.log('urlWithParameters...'+urlWithParameters);
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: urlWithParameters
            }
        }, false); //if you set true this will opens the new url in same window*/

    }

    get mainFrameClass(){
        var classText = this.isGreyedOut ? 'slds-m-around_medium greyed-out': 'slds-m-around_medium';
        return classText;
    }

    hideModalBox() {  
        this.isGreyedOut = false;
        this.vfPageURLToPreview = null;
    }


}