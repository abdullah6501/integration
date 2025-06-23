import { LightningElement, wire, track } from 'lwc';
import getChartData from '@salesforce/apex/PieChartController.getChartData';

export default class ChartDashboard extends LightningElement {
    @track chartType = 'bar';
    @track chartData = [];
    chartOptions = [
        { label: 'Bar Chart', value: 'bar' },
        { label: 'Line Chart', value: 'line' },
        { label: 'Pie Chart', value: 'pie' },
        { label: 'Scatter Plot', value: 'scatter' }
    ];
    @track width = '900';
    @track height = '300';
    @track color = '#4CAF50';
    @track angle = 'horizontal';


    @wire(getChartData)
    wiredChartData({ error, data }) {
        if (data) {
            this.chartData = data;
            console.log('chartdata', JSON.stringify(this.chartData));
        } else if (error) {
            console.error('Error retrieving data', error);
        }
    }

    handleChartTypeChange(event) {
        this.chartType = event.detail.value;
    }
}