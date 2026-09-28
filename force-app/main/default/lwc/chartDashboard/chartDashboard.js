import { LightningElement, wire, track } from 'lwc';
import getChartData from '@salesforce/apex/PieChartController.getChartData';
import getComparisonChartData from '@salesforce/apex/PieChartController.getComparisonChartData';
// import getPeopleCostingData from '@salesforce/apex/ActualPlanningController.getPeopleCostingData';
// import getGroupedResourceCosting from '@salesforce/apex/ActualPlanningController.getGroupedResourceCosting';

export default class ChartDashboard extends LightningElement {
    @track chartType = 'bar';
    @track chartData = [];
    @track xAxis = 'label';
    @track yAxis = 'value';
    chartOptions = [
        { label: 'Bar Chart', value: 'bar' },
        { label: 'Line Chart', value: 'line' },
        { label: 'Pie Chart', value: 'pie' },
        { label: 'Scatter Plot', value: 'scatter' },
        { label: 'Donut Chart', value: 'donut' },
        { label: 'Tree Map', value: 'treemap'},
        { label: 'Gantt Chart', value: 'gantt'},
        { label: 'Horizontal Bar Chart', value: 'horizontalbar' }
    ];
    @track width = '800';
    @track height = '500';
    @track color = 'skyblue';
    @track angle = 'horizontal'; // vertical, horizontal, angled

    // horizontalChartData = [
    //     { costing: 'Actual', amount: 3000 },
    //     { costing: 'Planning', amount: 1000 }
    // ];

    compareFields = ['goldPrice', 'silverPrice'];
    comparisonColors = {
        goldPrice: 'green',
        silverPrice: '#C0C0C0'
    };
    // comparisonColors = {
    //     Actual: '#0070d2',
    //     Planning: '#78c4f5'
    // };

    // chartData = [
    //     { task: 'Planning', start: '2025-06-01', end: '2025-07-01' },
    //     { task: 'Development', start: '2025-06-15', end: '2025-08-15' },
    //     { task: 'Testing', start: '2025-07-14', end: '2025-07-30' }
    //     // { task: 'Plan', start: '2025-06-01', end: '2025-07-01', color: '#0070d2' },
    //     // { task: 'Develop', start: '2025-06-15', end: '2025-08-15', color: 'orange' },
    //     // { task: 'Test', start: '2025-07-14', end: '2025-07-30', color: 'red' }
    // ];
    
    @wire(getComparisonChartData)
    wiredComparisonChartData({ error, data }) {
        if (data) {
            this.chartData = data;
            console.log('chartdata', JSON.stringify(this.chartData));
        } else if (error) {
            console.error('Error retrieving data', error);
        }   
    }

    // @wire(getChartData)
    // wiredChartData({ error, data }) {
    //     if (data) {
    //         this.chartData = data;
    //         console.log('chartdata', JSON.stringify(this.chartData));
    //     } else if (error) {
    //         console.error('Error retrieving data', error);
    //     }
    // }

    // ganttData = [
    //     { task: 'Design', start: '2025-06-01', end: '2025-06-05' },
    //     { task: 'Development', start: '2025-06-06', end: '2025-06-15' },
    //     { task: 'Testing', start: '2025-06-16', end: '2025-06-20' }
    // ];

    handleChartTypeChange(event) {
        this.chartType = event.detail.value;
    }
}