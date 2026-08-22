import { api, LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPeopleCostingData from '@salesforce/apex/ActualPlanningController.getPeopleCostingData';
import getGroupedResourceCosting from '@salesforce/apex/ActualPlanningController.getGroupedResourceCosting';

export default class StatusBarChart extends LightningElement {
    @api recordId;
    labourData = [];
    chartData = {};
    equipmentData = [];
    materialData = [];
    @track actualTreemapData = [];
    @track planningTreemapData = [];
    @track isLoading = false;
    
    wiredPeopleCostingResult;
    wiredGroupedResourceResult;

    selectedView = 'Individual';

    viewOptions = [
        { label: 'Individual', value: 'Individual' },
        { label: 'Overall', value: 'Overall' }
    ];

    comparisonColors = {
        Actual: '#0070d2',
        Planning: '#78c4f5'
    };

    compareFields = ['Actual', 'Planning'];

    @wire(getPeopleCostingData, { recordId: '$recordId' })
    wiredGetPeopleCostingData(result) {
        this.wiredPeopleCostingResult = result;
        const { error, data } = result;
        if (data) {
            this.labourData = [this.formatLabourData(data)];
            console.log('labour chartdata', JSON.stringify(this.labourData));
            this.calculateTreemapData();
        } else if (error) {
            console.error('Error retrieving people costing data', error);
        }
    }

    @wire(getGroupedResourceCosting, { recordId: '$recordId' })
    wiredGetGroupedResourceCosting(result) {
        this.wiredGroupedResourceResult = result;
        const { error, data } = result;
        if (data) {
            this.chartData = data;
            console.log('resource chartdata', JSON.stringify(this.chartData));
            this.formatChartData();
            this.calculateTreemapData();
        } else if (error) {
            console.error('Error retrieving grouped resource costing', error);
        }
    }

    formatLabourData(data) {
        const result = { label: 'Labor Costing' };
        data.forEach(entry => {
            result[entry.costing] = entry.amount;
        });
        return result;
    }

    formatChartData() {
        this.equipmentData = [this.formatCategoryData('Equipment', this.chartData.equipment)];
        this.materialData = [this.formatCategoryData('Materials Cost', this.chartData.material)];
        console.log('Equipment:', JSON.stringify(this.equipmentData));
        console.log('Materials:', JSON.stringify(this.materialData));        
    }

    formatCategoryData(categoryLabel, categoryArray) {
        const result = { label: categoryLabel };
        if (categoryArray && categoryArray.length > 0) {
            categoryArray.forEach(entry => {
                result[entry.costing] = entry.amount;
            });
        }
        return result;
    }

    handleViewChange(event) {
        this.selectedView = event.detail.value;
    
        if (this.selectedView === 'Overall') {
            this.calculateTreemapData();
        }
    }

    calculateTreemapData() {
        this.actualTreemapData = [
            { label: 'Labor', value: this.labourData[0]?.Actual || 0 },
            { label: 'Equipment', value: this.equipmentData[0]?.Actual || 0 },
            { label: 'Materials', value: this.materialData[0]?.Actual || 0 }
        ];
    
        this.planningTreemapData = [
            { label: 'Labor', value: this.labourData[0]?.Planning || 0 },
            { label: 'Equipment', value: this.equipmentData[0]?.Planning || 0 },
            { label: 'Materials', value: this.materialData[0]?.Planning || 0 }
        ];
    }   
    
    get isIndividualView() {
        return this.selectedView === 'Individual';
    }
    
    get isOverallView() {
        return this.selectedView === 'Overall';
    }        

    get summaryRows() {
        return [
            {
                index: 1,
                label: 'Labor',
                planned: this.labourData[0]?.Planning || 0,
                actual: this.labourData[0]?.Actual || 0,
                difference: (this.labourData[0]?.Planning || 0) - (this.labourData[0]?.Actual || 0),
                plannedFormatted: this.formatCurrency(this.labourData[0]?.Planning || 0),
                actualFormatted: this.formatCurrency(this.labourData[0]?.Actual || 0),
                differenceFormatted: this.formatCurrency((this.labourData[0]?.Planning || 0) - (this.labourData[0]?.Actual || 0))
            },
            {
                index: 2,
                label: 'Equipment\'s',
                planned: this.equipmentData[0]?.Planning || 0,
                actual: this.equipmentData[0]?.Actual || 0,
                difference: (this.equipmentData[0]?.Planning || 0) - (this.equipmentData[0]?.Actual || 0),
                plannedFormatted: this.formatCurrency(this.equipmentData[0]?.Planning || 0),
                actualFormatted: this.formatCurrency(this.equipmentData[0]?.Actual || 0),
                differenceFormatted: this.formatCurrency((this.equipmentData[0]?.Planning || 0) - (this.equipmentData[0]?.Actual || 0))
            },
            {
                index: 3,
                label: 'Materials',
                planned: this.materialData[0]?.Planning || 0,
                actual: this.materialData[0]?.Actual || 0,
                difference: (this.materialData[0]?.Planning || 0) - (this.materialData[0]?.Actual || 0),
                plannedFormatted: this.formatCurrency(this.materialData[0]?.Planning || 0),
                actualFormatted: this.formatCurrency(this.materialData[0]?.Actual || 0),
                differenceFormatted: this.formatCurrency((this.materialData[0]?.Planning || 0) - (this.materialData[0]?.Actual || 0))
            },
            {
                index: 4,
                label: 'Total',
                planned: this.totalPlanned,
                actual: this.totalActual,
                difference: this.totalDifference,
                plannedFormatted: this.totalPlannedFormatted,
                actualFormatted: this.totalActualFormatted,
                differenceFormatted: this.totalDifferenceFormatted
            }
        ];
    }

    get totalPlanned() {
        return (this.labourData[0]?.Planning || 0) + 
               (this.equipmentData[0]?.Planning || 0) + 
               (this.materialData[0]?.Planning || 0)  
    }

    get totalActual() {
        return (this.labourData[0]?.Actual || 0) + 
               (this.equipmentData[0]?.Actual || 0) + 
               (this.materialData[0]?.Actual || 0) 
    }

    get totalDifference() {
        return this.totalPlanned - this.totalActual;
    }

    get totalPlannedFormatted() {
        return this.formatCurrency(this.totalPlanned);
    }

    get totalActualFormatted() {
        return this.formatCurrency(this.totalActual);
    }

    get totalDifferenceFormatted() {
        return this.formatCurrency(this.totalDifference);
    }

    formatCurrency(amount) {
        if (amount === 0 || amount === null || amount === undefined) {
            return '0.00';
        }
        return amount.toLocaleString(undefined, {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handleRefresh() {
        this.isLoading = true;
        
        const refreshPromises = [];
        
        if (this.wiredPeopleCostingResult) {
            refreshPromises.push(refreshApex(this.wiredPeopleCostingResult));
        }
        
        if (this.wiredGroupedResourceResult) {
            refreshPromises.push(refreshApex(this.wiredGroupedResourceResult));
        }
        
        Promise.all(refreshPromises)
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Chart data refreshed successfully',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error refreshing data:', error);
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to refresh chart data',
                        variant: 'error'
                    })
                );
            });
    }
}
