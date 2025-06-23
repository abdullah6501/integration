import { LightningElement, track, wire } from 'lwc';
import getChartOfAccount from '@salesforce/apex/TrailBalance.getChartOfAccount';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFiscalYearRange from '@salesforce/apex/CommonUtility.getFiscalYearRange';
export default class TrailBalance extends NavigationMixin(LightningElement) {
    @track displayList = [];
    rawData = [];
    mapData = {};
    @track totalDebit = 0;
    @track totalCredit = 0;
    // @track noDataFound = true;

    @track fromDate;
    @track toDate;

    @wire(getFiscalYearRange)
    wiredFiscalYear({ error, data }) {
        if (data) {
            this.fromDate = data.startDate;
            console.log('Fiscal Year Start Date:', this.fromDate);
            console.log('Fiscal Year End Date:', data.endDate);
            this.toDate = data.endDate;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.fromDate = undefined;
            this.toDate = undefined;
            console.error('Error fetching fiscal year:', error);
        }
    }

    connectedCallback() {
        // const currentYear = new Date().getFullYear();
        // this.fromDate = `${currentYear}-04-01`;
        // this.toDate = `${currentYear+1}-03-31`;
        this.fetchData();
    }
    handleCOASearch(event) {
        const searchTerm = event.target.value.toLowerCase();

        if (!searchTerm) {
            // If search is empty, collapse all and show root nodes
            this.displayList = this.mapData['Null'].map(item => ({
                ...item,
                indentStyle: `padding-left:${item.level * 20}px;`,
                isExpanded: false,
                iconName: item.hasChildren ? 'utility:chevronright' : ''
            }));
            return;
        }

        // Find matching item(s) by name
        const matchedItems = this.rawData.filter(item => item.name.toLowerCase().includes(searchTerm));
        if (matchedItems.length === 0) {
            // No matches: show empty or show original data
            this.displayList = [];
            return;
        }

        const matchedIds = new Set();
        const allExpandedNodes = [];

        const collectWithAncestors = (item) => {
            if (!item) return;

            // Add item
            if (!matchedIds.has(item.id)) {
                matchedIds.add(item.id);
                allExpandedNodes.push(item);
            }

            // Add ancestors recursively
            if (item.parentId && item.parentId !== 'Null') {
                const parent = this.rawData.find(parent => parent.id === item.parentId);
                if (parent) {
                    collectWithAncestors(parent);
                }
            }

            // Also include children if the match is a parent
            const children = this.mapData[item.id] || [];
            for (let child of children) {
                if (!matchedIds.has(child.id)) {
                    matchedIds.add(child.id);
                    allExpandedNodes.push(child);
                }
            }
        };

        // Collect all matched items and their ancestors & children
        matchedItems.forEach(item => collectWithAncestors(item));

        // Sort displayList in original order, but only include matched items + related
        const buildDisplayList = (parentId = 'Null', level = 0) => {
            const list = [];
            const children = this.mapData[parentId] || [];
            for (let child of children) {
                if (matchedIds.has(child.id)) {
                    child.level = level;
                    child.indentStyle = `padding-left:${level * 20}px;`;
                    child.isExpanded = true;
                    child.iconName = child.hasChildren ? 'utility:chevrondown' : '';
                    list.push(child);
                    list.push(...buildDisplayList(child.id, level + 1));
                }
            }
            return list;
        };

        this.displayList = buildDisplayList();
        console.log('matched items:', matchedItems);
        
    }

    fetchData() {
        getChartOfAccount({ fromDate: this.fromDate, toDate: this.toDate })
            .then(data => {
                console.log('Fetched Data:', JSON.stringify(data));
                this.prepareData(data);
            })
            .catch(error => {
                console.error('Error fetching data:', error);
            });
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        // Console.log('toodate-->'+this.)
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    handleSearch() {
        this.fetchData();
    }

    prepareData(data) {
    // Step 1: Normalize data
    this.rawData = data.map(item => ({
        id: item.id,
        name: item.name,
        debit: item.debit || 0,
        credit: item.credit || 0,
        originalDebit: item.debit || 0,   // keep original for reference
        originalCredit: item.credit || 0,
        parentId: item.parentId || item.parentId1 || 'Null',
        isExpanded: false,
        iconName: 'utility:chevronright',
        hasChildren: false,
        level: 0
    }));

    // Step 2: Build maps
    this.mapData = {};
    const nodeMap = {};
    this.rawData.forEach(item => {
        nodeMap[item.id] = item;
        if (!this.mapData[item.parentId]) {
            this.mapData[item.parentId] = [];
        }
        this.mapData[item.parentId].push(item);
    });

    // Step 3: Mark items with children
    this.rawData.forEach(item => {
        if (this.mapData[item.id]) {
            item.hasChildren = true;
        }
    });

    // Step 4: Recursive aggregation
    const sumChildren = (node) => {
        let totalDebit = node.originalDebit;
        let totalCredit = node.originalCredit;

        const children = this.mapData[node.id] || [];
        for (let child of children) {
            child.level = node.level + 1;
            const childTotals = sumChildren(child);
            totalDebit += childTotals.debit;
            totalCredit += childTotals.credit;
        }

        node.debit = totalDebit;
        node.credit = totalCredit;
        return { debit: totalDebit, credit: totalCredit };
    };

    const rootNodes = this.mapData['Null'] || [];
    rootNodes.forEach(root => {
        root.level = 0;
        sumChildren(root);
    });

    // Step 5: Prepare display list (only root level initially)
    this.displayList = rootNodes.map(item => ({
        ...item,
        indentStyle: `padding-left:${item.level * 20}px;`
    }));

    // Step 6: Totals
    this.calculateTotals();
}



    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        const index = this.displayList.findIndex(item => item.id === id);
        const record = this.displayList[index];

        if (record.isExpanded) {
            this.collapseChildren(id, index);
            record.iconName = 'utility:chevronright';
        } else {
            this.expandChildren(id, index, record.level);
            record.iconName = 'utility:chevrondown';
        }

        record.isExpanded = !record.isExpanded;
        this.displayList = [...this.displayList];
    }

   handleItemClick(event) {
    const accountId = event.currentTarget.dataset.id;
    
    this[NavigationMixin.GenerateUrl]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: 'Ledger'
        },
        state: {
            c__selectedid: accountId,
            c__startDate: this.fromDate,
            c__endDate: this.toDate
        }
    }).then(url => {
        window.open(url, '_blank');
    });
}


    expandChildren(parentId, index, parentLevel) {
        const children = this.mapData[parentId]?.map(child => ({
            ...child,
            level: parentLevel + 1,
            indentStyle: `padding-left:${(parentLevel + 1) * 20}px;`
        })) || [];
        this.displayList.splice(index + 1, 0, ...children);
    }

    collapseChildren(parentId, index) {
        const parentLevel = this.displayList[index].level;
        let removeCount = 0;
        for (let i = index + 1; i < this.displayList.length; i++) {
            if (this.displayList[i].level > parentLevel) {
                removeCount++;
            } else {
                break;
            }
        }
        this.displayList.splice(index + 1, removeCount);
    }

    calculateTotals() {
        this.totalDebit = 0;
        this.totalCredit = 0;
    
        if (this.rawData && this.rawData.length > 0) {
            const topLevelParents = this.rawData.filter(item => item.parentId === 'Null');
            this.totalDebit = topLevelParents.reduce((sum, item) => sum + (item.debit || 0), 0);
            this.totalCredit = topLevelParents.reduce((sum, item) => sum + (item.credit || 0), 0);
        }
    }

    handleDownloadCSV() {
        try {
            if (this.noDataFound || !this.rawData || this.rawData.length === 0) {
                this.ShowToast('Error', 'No data available to download', 'error');
                return;
            }

            const csvContent = this.generateTrialBalanceCSV();

            const element = document.createElement('a');
            const encodedUri = encodeURI('data:text/csv;charset=utf-8,' + csvContent);
            element.setAttribute('href', encodedUri);
            
            const currentDate = new Date().toISOString().split('T')[0];
            const fileName = `Trial_Balance_${currentDate}.csv`;
            
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

    generateTrialBalanceCSV() {
        let csv = `Trial Balance Report\n`;
        csv += `From Date: ${this.fromDate}\n`;
        csv += `To Date: ${this.toDate}\n`;
        csv += `\n`;
        csv += 'Account Name,Debit,Credit\n';
        
        const flattenData = (parentId = 'Null', level = 0, result = []) => {
            const children = this.mapData[parentId] || [];
            children.forEach(child => {
                const indentedName = '  '.repeat(level) + child.name;
                result.push({
                    name: indentedName,
                    debit: child.debit || 0,
                    credit: child.credit || 0
                });
                
                if (this.mapData[child.id]) {
                    flattenData(child.id, level + 1, result);
                }
            });
            return result;
        };
    
        const flatData = flattenData();
        
        flatData.forEach(row => {
            const accountName = this.escapeCSVField(row.name);
            const debit = this.escapeCSVField(row.debit.toString());
            const credit = this.escapeCSVField(row.credit.toString());
            
            csv += `${accountName},${debit},${credit}\n`;
        });
        
        csv += `\nTotal,${this.totalDebit},${this.totalCredit}\n`;
        
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

    ShowToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}