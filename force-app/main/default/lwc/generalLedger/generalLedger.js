import { LightningElement, track, wire, api } from 'lwc';
import getGeneralLedger from '@salesforce/apex/GeneralLedgerCreator.getGeneralLedger';
import getChartAccChild from '@salesforce/apex/GeneralLedgerCreator.getChartAccChild';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserCurrency from '@salesforce/apex/GeneralLedgerCreator.getUserCurrency';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getNslog from '@salesforce/apex/InvoiceFormController.getNslog';
import { refreshApex } from '@salesforce/apex';

export default class LedgerSearch extends NavigationMixin(LightningElement) {
    @api selectedid = '';
    @api startDate = '';
    @api endDate = '';
    @track noDataFound = true;
    @track showGeneralLedgerTable = true;
    totalbalance = 0;
    totaldebited = 0;
    totalcredited = 0;
    OpeningBalance = 0;
    Openingdate = '';
    journlentryflag = true;
    data = [];    currencySymbol;    
    parametersReceived = false; // Flag to track if parameters are received
    
    // Store wired results for refreshApex
    wiredGeneralLedgerResult;
    wiredChartAccChildResult;
    wiredUserCurrencyResult;    connectedCallback() {
        console.log('connectedCallback called', this.selectedid);
        
        // window.location.reload();
        // Reset component data
        this.data = [];
        this.totalbalance = 0;
        this.totaldebited = 0;
        this.totalcredited = 0;
        this.OpeningBalance = 0;
        this.Openingdate = '';
        this.noDataFound = true;
        this.showGeneralLedgerTable = true;
        this.parametersReceived = false;

        // If we have stored parameters, trigger a search
        if (this.selectedid && this.startDate && this.endDate) {
            this.refreshApexData().then(() => {
                setTimeout(() => {
                    this.handleSearch();
                }, 100);
            });
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            console.log('Current page reference state:', currentPageReference.state);
            
            // Check if we have navigation parameters
            const navSelectedId = currentPageReference.state?.c__selectedid;
            const navStartDate = currentPageReference.state?.c__startDate;
            const navEndDate = currentPageReference.state?.c__endDate;
            // const navAccountName = currentPageReference.state?.c__accountName;
            
            if (navSelectedId && !this.parametersReceived) {
                this.selectedid = navSelectedId;  // Use consistent variable name
                this.startDate = navStartDate;
                this.endDate = navEndDate;
                // if (navAccountName) {
                //     this.selectedAccountName = navAccountName;
                //     console.log('Account name set from navigation:', this.selectedAccountName);
                // }
                this.parametersReceived = true;
                
                console.log('Navigation parameters received:', {
                    selectedid: this.selectedid,
                    startDate: this.startDate,
                    endDate: this.endDate
                });
                
                // Refresh apex data and then trigger search
                this.refreshApexData().then(() => {
                    setTimeout(() => {
                        this.handleSearch();
                    }, 100);
                });
            }
        }
    }

    // Method to refresh all apex data
    async refreshApexData() {
        try {
            const refreshPromises = [];
            
            // Refresh wired results if they exist
            if (this.wiredGeneralLedgerResult) {
                refreshPromises.push(refreshApex(this.wiredGeneralLedgerResult));
            }
            if (this.wiredChartAccChildResult) {
                refreshPromises.push(refreshApex(this.wiredChartAccChildResult));
            }
            if (this.wiredUserCurrencyResult) {
                refreshPromises.push(refreshApex(this.wiredUserCurrencyResult));
            }
            
            // Wait for all refreshes to complete
            await Promise.all(refreshPromises);
            console.log('All apex data refreshed successfully');
            
        } catch (error) {
            console.error('Error refreshing apex data:', error);
        }
    }

    ns;
    objectApiName = 'Journal_Entry__c';
    @wire(getNslog)
    managedNamespacewire({ error, data }) {
        if (data) {
            this.ns = data.nameSpace != 'null' ? data.nameSpace : '';
            this.objectApiName = data.nameSpace != 'null' ? data.nameSpace + this.objectApiName : this.objectApiName;
            console.log(this.objectApiName);
        }
    }

    handlestartdatechange(event) {
        this.startDate = event.target.value;
        this.parametersReceived = false; // Reset flag when user manually changes date
    }

    handleenddatechange(event) {
        this.endDate = event.target.value;
        this.parametersReceived = false; // Reset flag when user manually changes date
    }

    @track selectedAccountName = '';

    handleValueSelectedOnAccount(event) {

        const selectedItem = event.detail;
        if (selectedItem && event.detail.id) {
            this.selectedid = selectedItem.id;
            this.selectedAccountName = selectedItem.mainField;

        } else {
            this.selectedid = '';
            this.selectedAccountName = '';
        }
        this.parametersReceived = false; // Reset flag when user manually selects account
    }

    handleJournalEntryClick(event) {
        let recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: this.objectApiName,
                    actionName: 'view'
                }
            });
        }
    }

    handleDownloadCSV() {
        try {
            if (this.noDataFound) {
                this.ShowToast('Error', 'No data available to download', 'error');
                return;
            }

            let csvContent = '';
            
            if (this.showGeneralLedgerTable && this.data.length > 0) {
                // General Ledger CSV
                csvContent = this.generateGeneralLedgerCSV();
            } else if (!this.showGeneralLedgerTable && this.summaryData.length > 0) {
                // Summary CSV
                csvContent = this.generateSummaryCSV();
            } else {
                this.ShowToast('Error', 'No data available to download', 'error');
                return;
            }

            const element = document.createElement('a');
            
            const encodedUri = encodeURI('data:text/csv;charset=utf-8,' + csvContent);
            element.setAttribute('href', encodedUri);
            
            const currentDate = new Date().toISOString().split('T')[0];
            const fileName = this.showGeneralLedgerTable ? 
                `General_Ledger_${currentDate}.csv` : 
                `Account_Summary_${currentDate}.csv`;
            
            element.setAttribute('download', fileName);
            
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            
            setTimeout(() => {
                document.body.removeChild(element);
            }, 100);
            
            this.ShowToast('Success', 'CSV file downloaded successfully', 'success');
            
        } catch (error) {
            console.error('Error downloading CSV:', error);
            this.ShowToast('Error', 'Failed to download CSV file', 'error');
        }
    }

    handleDownloadCSVAlternative() {
        try {
            if (this.noDataFound) {
                this.ShowToast('Error', 'No data available to download', 'error');
                return;
            }

            let csvContent = '';
            
            if (this.showGeneralLedgerTable && this.data.length > 0) {
                csvContent = this.generateGeneralLedgerCSV();
            } else if (!this.showGeneralLedgerTable && this.summaryData.length > 0) {
                csvContent = this.generateSummaryCSV();
            } else {
                this.ShowToast('Error', 'No data available to download', 'error');
                return;
            }

            const element = document.createElement('a');
            const file = new Blob([csvContent], { type: 'application/octet-stream' });
            element.href = URL.createObjectURL(file);
            
            const currentDate = new Date().toISOString().split('T')[0];
            const fileName = this.showGeneralLedgerTable ? 
                `General_Ledger_${currentDate}.csv` : 
                `Account_Summary_${currentDate}.csv`;
            
            element.download = fileName;
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            
            setTimeout(() => {
                URL.revokeObjectURL(element.href);
                document.body.removeChild(element);
            }, 100);
            
            this.ShowToast('Success', 'CSV file downloaded successfully', 'success');
            
        } catch (error) {
            console.error('Error downloading CSV:', error);
            this.ShowToast('Error', 'Failed to download CSV file', 'error');
        }
    }
    
    generateGeneralLedgerCSV() {
        const accountName = this.selectedAccountName || 'N/A';
        
        let csv = `General Ledger Report\n`;
        csv += `Account Name: ${accountName}\n`;
        csv += `Start Date: ${this.startDate}\n`;
        csv += `End Date: ${this.endDate}\n`;
        csv += `\n`; 
        
        csv += 'Date,Transaction Details,Account Name,Debit,Credit,Balance\n';
        
        csv += `,,,"Opening Balance",,${this.currencySymbol} ${this.OpeningBalance}\n`;
        
        this.data.forEach(row => {
            const date = this.escapeCSVField(row.GeneralLedgerEntrydate);
            const transactionDetails = this.escapeCSVField(row.JournalEntryName);
            const accountName = this.escapeCSVField(row.Accountname);
            const debit = this.escapeCSVField(row.debited === '-' ? '' : row.debited);
            const credit = this.escapeCSVField(row.credited === '-' ? '' : row.credited);
            const balance = this.escapeCSVField(`${this.currencySymbol} ${row.ClosingBalance}`);
            
            csv += `${date},${transactionDetails},${accountName},${debit},${credit},${balance}\n`;
        });
        
        csv += `\nOverall Summary,,,${this.currencySymbol} ${this.totalcredited},${this.currencySymbol} ${this.totaldebited},${this.currencySymbol} ${this.totalbalance}\n`;
        
        return csv;
    }
    
    generateSummaryCSV() {
        const accountName = this.selectedAccountName || 'N/A';
        
        let csv = `Account Summary Report\n`;
        csv += `Account Name: ${accountName}\n`;
        csv += `Start Date: ${this.startDate || 'N/A'}\n`;
        csv += `End Date: ${this.endDate || 'N/A'}\n`;
        csv += `\n`;
        
        csv += 'Account Name,Opening Balance,Closing Balance\n';
        
        this.summaryData.forEach(row => {
            const accountName = this.escapeCSVField(row.AccountName);
            const openingBalance = this.escapeCSVField(`${this.currencySymbol} ${row.OpeningBalance}`);
            const closingBalance = this.escapeCSVField(`${this.currencySymbol} ${row.BalanceAmount}`);
            
            csv += `${accountName},${openingBalance},${closingBalance}\n`;
        });
        
        return csv;
    }

    escapeCSVField(field) {
        if (field === null || field === undefined) {
            return '';
        }
        
        const stringField = String(field);
        
        if (stringField.includes(',') || stringField.includes('\n') || stringField.includes('"')) {
            return '"' + stringField.replace(/"/g, '""') + '"';
        }
        
        return stringField;
    }

    handleSearch() {
        console.log('handleSearch called with:', {
            selectedid: this.selectedid,
            startDate: this.startDate,
            endDate: this.endDate
        });

        // Refresh apex data before searching
        this.refreshApexData().then(() => {
            getUserCurrency().then(currencyCode => {
                this.currencySymbol = currencyCode;
            });
            console.log('Currency-->' + this.currencySymbol);

            if (!this.selectedid) {
                this.ShowToast('Failure!', 'Please select a Chart of Account.', 'error');
                return;
            }        getChartAccChild({ chartOfAccount: this.selectedid })
                .then(result => {
                    console.log('result-------------->' + JSON.stringify(result));
                    // Clear previous data
                    this.data = [];
                    this.totalbalance = 0;
                    this.totaldebited = 0;
                    this.totalcredited = 0;
                    
                    if (result.length > 0) {
                        this.noDataFound = false;
                        this.showGeneralLedgerTable = false;
                        this.summaryData = result;
                        this.startDate = '';
                        this.endDate = '';
                    } else {
                        if (!this.startDate || !this.endDate) {
                            this.ShowToast('Failure!', 'Choose Start and End date.', 'error');
                            return;
                        }
                        getGeneralLedger({ chartOfAccount: this.selectedid, startdate: this.startDate, enddate: this.endDate })
                            .then(result => {
                                this.wiredGeneralLedgerResult=result;
                                console.log('result-->' + JSON.stringify(result));
                                if (result == null) {
                                    this.noDataFound = true;
                                    this.showGeneralLedgerTable = true;
                                    this.data = [];
                                    this.totalbalance = 0;
                                } else if (result.length > 0) {
                                    this.noDataFound = false;
                                    this.showGeneralLedgerTable = true;
                                    this.totalcredited = 0;
                                    this.totaldebited = 0;
                                    result.sort((a, b) => new Date(a.GeneralLedgerEntrydate) - new Date(b.GeneralLedgerEntrydate));
                                    this.data = result.map(result => {
                                        var debited = 0;
                                        var credited = 0;
                                        var Accountname = '';
                                        var ClosingBalance = 0;
                                        ClosingBalance = result.ClosingBalance;
                                        if (this.selectedid != result.DebitCOA) {
                                            debited = result.DebitAmount;
                                            this.totaldebited += debited;
                                            Accountname = result.DebitChartAccountName;
                                        } else {
                                            credited = result.creditAmount;
                                            this.totalcredited += credited;
                                            Accountname = result.CreditChartAccountName;
                                        }
                                        return {
                                            ...result,
                                            GeneralLedgerEntrydate: this.formatDate(result.GeneralLedgerEntrydate),
                                            debited: credited !== 0 ? this.currencySymbol + ' ' + credited : '-',
                                            credited: debited !== 0 ? this.currencySymbol + ' ' + debited : '-',
                                            Accountname,
                                            debitClass: this.getAmountClass(debited),
                                            creditClass: this.getAmountClass(credited),
                                            balanceClass: this.getAmountClassred(ClosingBalance)
                                        };
                                    })
                                    this.totalbalance = this.data[this.data.length - 1].ChartOfAccountsBalance;
                                    this.OpeningBalance = this.data[0].OpeningBalance;
                                    this.Openingdate = this.data[0].GeneralLedgerEntrydate;
                                };
                            }).catch(error => {
                                console.error('Error in getGeneralLedger:', error);
                            });
                    }
                })
                .catch(error => {
                    console.error('Error in getChartAccChild:', error);
                });
        });
    }

    getAmountClass(amount) {
        if (amount < 0) {
            return 'red';
        }
        return 'green';
    }

    getAmountClassred(amount) {
        if (amount < 0) {
            return 'red';
        }
        return 'black';
    }

    formatDate(dateString) {
        if (!dateString) return '';

        const date = new Date(dateString);
        const options = { day: '2-digit', month: 'short', year: 'numeric' };

        return new Intl.DateTimeFormat('en-GB', options).format(date);
    }

    ShowToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    renderedCallback() {
        if (this.wiredGeneralLedgerResult) {
            refreshApex(this.wiredGeneralLedgerResult);
        }
    }
}