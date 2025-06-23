import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateFinanceReport from "@salesforce/apex/FinanceReportController.generateFinanceReport";

export default class CustomFinanceConsolidatedReport extends LightningElement {
    currentAssetMap = new Map();    
    
    handleDownload() {
        let csvData = [];
        let headers = ['Chart of Account Name', String(new Date().getFullYear()), String(new Date().getFullYear()-1), String(new Date().getFullYear()-2)];
        
        // Function to escape CSV values
        const escapeCSV = (value) => {
            if (value === null || value === undefined) return '';
            const stringValue = String(value);
            if (stringValue.includes(',') || stringValue.includes('\n') || stringValue.includes('"')) {
                return `"${stringValue.replace(/"/g, '""')}"`;
            }
            return stringValue;
        };

        // Function to create row data
        const createRowData = (row) => {
            return [
                escapeCSV(row.chartOfAccountName || 'Subtotal'),
                escapeCSV(row.amountInCurrentYear),
                escapeCSV(row.amountInCurrentYearMinusOne),
                escapeCSV(row.amountInCurrentYearMinusTwo)
            ].join(',');
        };

        csvData.push(headers.join(','));

        if (this.assetFlag) {
            // Current Assets
            csvData.push('\nCurrent Assets');
            this.currentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });

            // Non-Current Assets
            csvData.push('\nFixed Assets');
            this.nonCurrentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });

            // Current Equity
            csvData.push('\nOwners Equity');
            this.currentEquityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });

            // Non-Current Equity
            csvData.push('\nShareholder Equity');
            this.nonCurrentEquityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });

            // Current Liabilities
            csvData.push('\nCurrent Liabilities');
            this.currentLiabilityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });

            // Non-Current Liabilities
            csvData.push('\nNon-Current Liabilities');
            this.nonCurrentLiabilityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });
        } else if (this.revenueFlag) {
            // Gross Profit
            csvData.push('\nGross Profit');
            this.currentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });

            // Operating Profit
            csvData.push('\nOperating Profit');
            this.nonCurrentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });
        } else if (this.cashFlowFlag) {
            // Cash Flows from Operating Activities
            csvData.push('\nCash Flows from Operating Activities');
            this.currentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });

            // Cash Flows from Investing Activities
            csvData.push('\nCash Flows from Investing Activities');
            this.nonCurrentAssetList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || '',
                ];
                csvData.push(rowData.join(','));
            });
            // Current Liabilities
            csvData.push('\nCurrent Liabilities');
            this.currentLiabilityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });

            // Non-Current Liabilities
            csvData.push('\nNon-Current Liabilities');
            this.nonCurrentLiabilityList.forEach(row => {
                let rowData = [
                    row.chartOfAccountName || 'Subtotal',
                    row.amountInCurrentYear || '',
                    row.amountInCurrentYearMinusOne || '',
                    row.amountInCurrentYearMinusTwo || ''
                ];
                csvData.push(rowData.join(','));
            });
        }        // Create the CSV content
        const csv = csvData.join('\n');
        
        // Create a download link using a data URL
        try {
            const fileName = this.value ? `${this.value}_financial_report.csv` : 'financial_report.csv';
            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
            const link = document.createElement('a');
            link.setAttribute('href', encodedUri);
            link.setAttribute('download', fileName);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            console.error('Error downloading CSV:', error);
            // Show error toast
            const event = new ShowToastEvent({
                title: 'Error',
                message: 'Error downloading the report',
                variant: 'error',
            });
            this.dispatchEvent(event);
        }
    }
    nonCurrentAssetMap = new Map();
    currentEquityMap = new Map();
    nonCurrentEquityMap = new Map();
    currentLiabilityMap = new Map();
    nonCurrentLiabilityMap = new Map();
    currentAssetLocalList = [];
    nonCurrentAssetLocalList = [];
    currentEquityLocalList = [];
    nonCurrentEquityLocalList = [];
    currentLiabilityLocalList = [];
    nonCurrentLiabilityLocalList = [];
    showDropdown = true;
    assetFlag = false;
    revenueFlag = false;
    cashFlowFlag = false;
    currentAssetList = [];
    nonCurrentAssetList = [];
    currentEquityList = [];
    nonCurrentEquityList = [];
    currentLiabilityList = [];
    nonCurrentLiabilityList = [];
    @track value;
    get options() {
        return [
                 { label: 'Consolidated Finance', value: 'Asset' },
                 { label: 'Revenue', value: 'Revenue' },
                 { label: 'Cash flows', value: 'CashFlows' }
               ];
    }
    assetColumns = [
        { label: "Chart of Account Name", fieldName : "chartOfAccountName"},
        { label: String(new Date().getFullYear()), fieldName: "amountInCurrentYear" },
        { label: String(new Date().getFullYear()-1), fieldName: "amountInCurrentYearMinusOne" },
        { label: String(new Date().getFullYear()-2), fieldName: "amountInCurrentYearMinusTwo" },

    ];
    equityColumns = [
        { label: "Chart of Account Name", fieldName : "chartOfAccountName"},
        { label: String(new Date().getFullYear()), fieldName: "amountInCurrentYear" },
        { label: String(new Date().getFullYear()-1), fieldName: "amountInCurrentYearMinusOne" },
        { label: String(new Date().getFullYear()-2), fieldName: "amountInCurrentYearMinusTwo" },
    ];
    liabilityColumns = [
        { label: "Chart of Account Name", fieldName : "chartOfAccountName"},
        { label: String(new Date().getFullYear()), fieldName: "amountInCurrentYear" },
        { label: String(new Date().getFullYear()-1), fieldName: "amountInCurrentYearMinusOne" },
        { label: String(new Date().getFullYear()-2), fieldName: "amountInCurrentYearMinusTwo" },
    ];

    handleChange(event) {
        this.value = event.detail.value;
     }

    showErrorToast() {
        const evt = new ShowToastEvent({
            title: 'Report Selection error',
            message: 'Please select any one type of report',
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    initializeValue(){
        this.currentAssetList = [];
        this.nonCurrentAssetList = [];
        this.currentEquityList = [];
        this.nonCurrentEquityList = [];
        this.currentLiabilityList = [];
        this.nonCurrentLiabilityList = [];
    }

    handleClick() {
        if(this.value == null || this.value === '' ){
            this.showErrorToast();
        } else {
            generateFinanceReport({ inpValue:  this.value})
            .then((result) => {
                let financeValues = JSON.parse(result);
                let subTotalRow = {};
                this.initializeValue();
                if(financeValues.currentAssets && financeValues.currentAssets.length > 0){
                    financeValues.currentAssets.forEach((element) => {
                        if (this.currentAssetMap.get(element.chartOfAccountName) == null) {
                            this.currentAssetMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.currentAssetMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.currentAssetMap.set(element.chartOfAccountName, element); 
                        }
                    });
                    this.currentAssetLocalList = Array.from(
                        this.currentAssetMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.currentAssetLocalList.forEach((element) => {
                        this.currentAssetList.push(element.value);
                    });
    
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.currentAssetList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.currentAssetList.push(subTotalRow);
                }
                
                if(financeValues.nonCurrentAssets && financeValues.nonCurrentAssets.length > 0){
                    financeValues.nonCurrentAssets.forEach((element) => {
                        if (this.nonCurrentAssetMap.get(element.chartOfAccountName) == null) {
                            this.nonCurrentAssetMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.nonCurrentAssetMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.nonCurrentAssetMap.set(element.chartOfAccountName, element); 
                        }
                    });
                    this.nonCurrentAssetLocalList = Array.from(
                        this.nonCurrentAssetMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.nonCurrentAssetLocalList.forEach((element) => {
                        this.nonCurrentAssetList.push(element.value);
                    });
                    subTotalRow = {};
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.nonCurrentAssetList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.nonCurrentAssetList.push(subTotalRow);
                } 
    
                this.initialValue = true;
                if(financeValues.currentEquity && financeValues.currentEquity.length > 0){
                    financeValues.currentEquity.forEach((element) => {
                        if (this.currentEquityMap.get(element.chartOfAccountName) == null) {
                            this.currentEquityMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.currentEquityMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.currentEquityMap.set(element.chartSubCategory, element); 
                        }
                    });
                    this.currentEquityLocalList = Array.from(
                        this.currentEquityMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.currentEquityLocalList.forEach((element) => {
                        this.currentEquityList.push(element.value);
                    });
                    subTotalRow = {};
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.currentEquityList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.currentEquityList.push(subTotalRow);
                
                }
    
                
                if(financeValues.nonCurrentEquity && financeValues.nonCurrentEquity.length > 0){
                    financeValues.nonCurrentEquity.forEach((element) => {
                        if (this.nonCurrentEquityMap.get(element.chartOfAccountName) == null) {
                            this.nonCurrentEquityMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.nonCurrentEquityMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.nonCurrentEquityMap.set(element.chartOfAccountName, element); 
                        }
                    });
                    this.nonCurrentEquityLocalList = Array.from(
                        this.nonCurrentEquityMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.nonCurrentEquityLocalList.forEach((element) => {
                        this.nonCurrentEquityList.push(element.value);
                    });
                    subTotalRow = {};
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.nonCurrentEquityList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.nonCurrentEquityList.push(subTotalRow);
                }
                if(financeValues.currentLiability && financeValues.currentLiability.length > 0){
                    financeValues.currentLiability.forEach((element) => {
                        if (this.currentLiabilityMap.get(element.chartOfAccountName) == null) {
                            this.currentLiabilityMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.currentLiabilityMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.currentLiabilityMap.set(element.chartSubCategory, element); 
                        }
                    });
                    this.currentLiabilityLocalList = Array.from(
                        this.currentLiabilityMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.currentLiabilityLocalList.forEach((element) => {
                        this.currentLiabilityList.push(element.value);
                    });
                    subTotalRow = {};
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.currentLiabilityList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.currentLiabilityList.push(subTotalRow);
                }
                if(financeValues.nonCurrentLiability && financeValues.nonCurrentLiability.length > 0){
                    financeValues.nonCurrentLiability.forEach((element) => {
                        if (this.nonCurrentLiabilityMap.get(element.chartOfAccountName) == null) {
                            this.nonCurrentLiabilityMap.set(element.chartOfAccountName, element);
                        } else {
                            let ele = this.nonCurrentLiabilityMap.get(element.chartOfAccountName);
                            element.amountInCurrentYearMinusTwo = (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo) == null ? 0 : (ele.amountInCurrentYearMinusTwo + element.amountInCurrentYearMinusTwo);
                            element.amountInCurrentYearMinusOne = (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne) == null ? 0 : (ele.amountInCurrentYearMinusOne + element.amountInCurrentYearMinusOne);
                            element.amountInCurrentYear = (ele.amountInCurrentYear + element.amountInCurrentYear) == null ? 0 : (ele.amountInCurrentYear + element.amountInCurrentYear);
                            this.nonCurrentLiabilityMap.set(element.chartOfAccountName, element); 
                        }
                    });
                    this.nonCurrentLiabilityLocalList = Array.from(
                        this.nonCurrentLiabilityMap,
                        ([name, value]) => ({ name, value })
                    );
                    this.nonCurrentLiabilityLocalList.forEach((element) => {
                        this.nonCurrentLiabilityList.push(element.value);
                    });
                    subTotalRow = {};
                    subTotalRow.amountInCurrentYear = 0;
                    subTotalRow.amountInCurrentYearMinusOne = 0;
                    subTotalRow.amountInCurrentYearMinusTwo = 0;
                    this.nonCurrentLiabilityList.forEach((elem) => {
                        subTotalRow.amountInCurrentYear = subTotalRow.amountInCurrentYear + elem.amountInCurrentYear;
                        subTotalRow.amountInCurrentYearMinusOne = subTotalRow.amountInCurrentYearMinusOne + elem.amountInCurrentYearMinusOne;
                        subTotalRow.amountInCurrentYearMinusTwo = subTotalRow.amountInCurrentYearMinusTwo + elem.amountInCurrentYearMinusTwo;
                    });
                    this.nonCurrentLiabilityList.push(subTotalRow);
                }
            })
    
            .catch((error) => {
                console.log("inside catch");
                console.log(error);
            });
            if(this.value === 'Asset'){
                this.assetFlag = true;
                this.revenueFlag = false;
                this.cashFlowFlag = false;
            } else if(this.value === 'Revenue'){
                this.assetFlag = false;
                this.revenueFlag = true;
                this.cashFlowFlag = false;
            } else if(this.value === 'CashFlows'){
                this.assetFlag = false;
                this.revenueFlag = false;
                this.cashFlowFlag = true;
            }
        }
        
    }
    

    handlePrint() {
        window.print();
    }
    connectedCallback(){
        console.log('inside connected callback');
    }
}