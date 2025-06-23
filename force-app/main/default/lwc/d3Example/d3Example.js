import { LightningElement, api } from 'lwc';

export default class D3Example extends LightningElement {
    @api chartData;
    @api chartType;
    @api xAxis;
    @api yAxis;

    d3Loaded = false;

    renderedCallback() {
        console.log('enter rendercallback-------<<<<<<<<>>');
        console.log('chartData', JSON.stringify(this.chartData));
        
        if (this.d3Loaded || !this.chartData.length) return;
        console.log('after if');
        
        const script = document.createElement('script');
        console.log('script', script);
        
        script.src = 'https://d3js.org/d3.v7.min.js';
        console.log('script src', script.src);
        script.onload = () => {
            this.d3Loaded = true;
            console.log('d3 loaded', this.d3Loaded);
            this.renderChart();

        };
        this.template.querySelector('.chart-container').appendChild(script);
    }

    renderChart() {
        console.log('render chart---->');
        
        const container = this.template.querySelector('.chart-container');
        const tooltip = d3.select(this.template.querySelector('.tooltip'));
        container.innerHTML = '';

        const width = 500, height = 400;
        const margin = { top: 20, right: 30, bottom: 50, left: 50 };
        const svg = d3.select(container)
            .append('svg')
            .attr('width', width)
            .attr('height', height);

        const chartWidth = width - margin.left - margin.right;
        const chartHeight = height - margin.top - margin.bottom;
        const g = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`);

        const x = d3.scaleBand()
            .domain(this.chartData.map(d => d[this.xAxis]))
            .range([0, chartWidth])
            .padding(0.5);

        const y = d3.scaleLinear()
            .domain([0, d3.max(this.chartData, d => d[this.yAxis])])
            .range([chartHeight, 0]);

        const showTooltip = (event, d) => {
            tooltip
                .style('display', 'block')
                .text(`${d[this.xAxis]}: ₹${d[this.yAxis]}`);
        };

        const moveTooltip = (event) => {
            tooltip
                .style('left', (event.pageX + 10) + 'px')
                .style('top', (event.pageY - 20) + 'px');
        };

        const hideTooltip = () => tooltip.style('display', 'none');

        if (this.chartType === 'bar') {
            g.selectAll('.bar')
                .data(this.chartData)
                .enter()
                .append('rect')
                .attr('class', 'bar')
                .attr('x', d => x(d[this.xAxis]))
                .attr('y', d => y(d[this.yAxis]))
                .attr('width', x.bandwidth())
                .attr('height', d => chartHeight - y(d[this.yAxis]))
                .attr('fill', '#69b3a2')
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this.chartType === 'line') {
            const line = d3.line()
                .x(d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .y(d => y(d[this.yAxis]));

            g.append('path')
                .datum(this.chartData)
                .attr('fill', 'none')
                .attr('stroke', 'steelblue')
                .attr('stroke-width', 2)
                .attr('d', line);

            g.selectAll('circle')
                .data(this.chartData)
                .enter()
                .append('circle')
                .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .attr('cy', d => y(d[this.yAxis]))
                .attr('r', 5)
                .attr('fill', 'steelblue')
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this.chartType === 'pie') {
            container.innerHTML = '';

            const radius = Math.min(chartWidth, chartHeight) / 2;
            const svgPie = d3.select(container)
                .append('svg')
                .attr('width', width)
                .attr('height', height)
                .append('g')
                .attr('transform', `translate(${width / 2}, ${height / 2})`);

            const color = d3.scaleOrdinal(d3.schemeCategory10);
            const pie = d3.pie().value(d => d[this.yAxis]);
            const arc = d3.arc().innerRadius(0).outerRadius(radius);

            const arcs = svgPie.selectAll('arc')
                .data(pie(this.chartData))
                .enter()
                .append('g');

            arcs.append('path')
                .attr('d', arc)
                .attr('fill', d => color(d.data[this.xAxis]))
                .on('mouseover', (event, d) => showTooltip(event, d.data))
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this.chartType === 'scatter') {
            g.selectAll('circle')
                .data(this.chartData)
                .enter()
                .append('circle')
                .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .attr('cy', d => y(d[this.yAxis]))
                .attr('r', 6)
                .attr('fill', 'orange')
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        }

        g.append('g').attr('transform', `translate(0, ${chartHeight})`).call(d3.axisBottom(x));
        g.append('g').call(d3.axisLeft(y));
    }
}


// import { LightningElement, track, wire } from 'lwc';
// import getChartData from '@salesforce/apex/PieChartController.getChartData';

// export default class D3Example extends LightningElement {
//     @track chartType = 'bar';
//     chartData = [];
//     d3Loaded = false;
//     dataLoaded = false;

//     chartOptions = [
//         { label: 'Bar Chart', value: 'bar' },
//         { label: 'Line Chart', value: 'line' },
//         { label: 'Pie Chart', value: 'pie' },
//         { label: 'Scatter Plot', value: 'scatter' }
//     ];

//     @wire(getChartData)
//     wiredData({ error, data }) {
//         if (data) {
//             this.chartData = data;
//             this.dataLoaded = true;
//             this.tryRenderChart();
//         } else if (error) {
//             console.error('Apex Error', error);
//         }
//     }

//     renderedCallback() {
//         if (this.d3Loaded) return;

//         const script = document.createElement('script');
//         script.src = 'https://d3js.org/d3.v7.min.js';
//         script.onload = () => {
//             this.d3Loaded = true;
//             this.tryRenderChart();
//         };
//         script.onerror = () => console.error('D3 failed to load');
//         this.template.querySelector('.chart-container').appendChild(script);
//     }

//     handleChartTypeChange(event) {
//         this.chartType = event.detail.value;
//         this.tryRenderChart();
//     }

//     tryRenderChart() {
//         if (this.d3Loaded && this.dataLoaded) {
//             this.renderChart();
//         }
//     }

//     renderChart() {
//         const container = this.template.querySelector('.chart-container');
//         const tooltip = d3.select(this.template.querySelector('.tooltip'));
//         container.innerHTML = '';

//         const width = 500;
//         const height = 400;
//         const margin = { top: 20, right: 30, bottom: 50, left: 50 };
//         const svg = d3.select(container)
//             .append('svg')
//             .attr('width', width)
//             .attr('height', height);

//         const chartWidth = width - margin.left - margin.right;
//         const chartHeight = height - margin.top - margin.bottom;
//         const g = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`);

//         const x = d3.scaleBand()
//             .domain(this.chartData.map(d => d.label))
//             .range([0, chartWidth])
//             .padding(0.5);

//         const y = d3.scaleLinear()
//             .domain([0, d3.max(this.chartData, d => d.value)])
//             .range([chartHeight, 0]);

//         g.append('g')
//             .attr('transform', `translate(0, ${chartHeight})`)
//             .call(d3.axisBottom(x));

//         g.append('g')
//             .call(d3.axisLeft(y));

//         // TOOLTIP
//         const showTooltip = (event, d) => {
//             tooltip
//                 .style('display', 'block')
//                 .text(`${d.label}: ₹${d.value}`);
//         };

//         const moveTooltip = (event) => {
//             tooltip
//                 .style('left', (event.pageX + 10) + 'px')
//                 .style('top', (event.pageY - 20) + 'px');
//         };

//         const hideTooltip = () => {
//             tooltip.style('display', 'none');
//         };

//         // CHART
//         if (this.chartType === 'bar') {
//             g.selectAll('.bar')
//                 .data(this.chartData)
//                 .enter()
//                 .append('rect')
//                 .attr('class', 'bar')
//                 .attr('x', d => x(d.label))
//                 .attr('y', d => y(d.value))
//                 .attr('width', x.bandwidth())
//                 .attr('height', d => chartHeight - y(d.value))
//                 .attr('fill', '#69b3a2')
//                 .on('mouseover', showTooltip)
//                 .on('mousemove', moveTooltip)
//                 .on('mouseout', hideTooltip);

//         } else if (this.chartType === 'line') {
//             const line = d3.line()
//                 .x(d => x(d.label) + x.bandwidth() / 2)
//                 .y(d => y(d.value));

//             g.append('path')
//                 .datum(this.chartData)
//                 .attr('fill', 'none')
//                 .attr('stroke', 'steelblue')
//                 .attr('stroke-width', 2)
//                 .attr('d', line);

//             g.selectAll('circle')
//                 .data(this.chartData)
//                 .enter()
//                 .append('circle')
//                 .attr('cx', d => x(d.label) + x.bandwidth() / 2)
//                 .attr('cy', d => y(d.value))
//                 .attr('r', 5)
//                 .attr('fill', 'steelblue')
//                 .on('mouseover', showTooltip)
//                 .on('mousemove', moveTooltip)
//                 .on('mouseout', hideTooltip);

//         } 
//         else if (this.chartType === 'pie') {
//             container.innerHTML = ''; 
        
//             const radius = Math.min(chartWidth, chartHeight) / 2;
//             const svgPie = d3.select(container)
//                 .append('svg')
//                 .attr('width', width)
//                 .attr('height', height)
//                 .append('g')
//                 .attr('transform', `translate(${width / 2}, ${height / 2})`);
        
//             const color = d3.scaleOrdinal(d3.schemeCategory10);
//             const pie = d3.pie().value(d => d.value);
//             const arc = d3.arc().innerRadius(0).outerRadius(radius);
        
//             const arcs = svgPie.selectAll('arc')
//                 .data(pie(this.chartData))
//                 .enter()
//                 .append('g');
        
//             arcs.append('path')
//                 .attr('d', arc)
//                 .attr('fill', d => color(d.data.label))
//                 .on('mouseover', (event, d) => showTooltip(event, d.data))
//                 .on('mousemove', moveTooltip)
//                 .on('mouseout', hideTooltip);
        
//             // arcs.append('text')
//             //     .attr('transform', d => `translate(${arc.centroid(d)})`)
//             //     .attr('text-anchor', 'middle')
//             //     .style('fill', '#fff')
//             //     .style('font-size', '12px')
//             //     .style('pointer-events', 'none') 
//             //     .text(d => d.data.label);
//         }
        
//         else if (this.chartType === 'scatter') {
//             g.selectAll('circle')
//                 .data(this.chartData)
//                 .enter()
//                 .append('circle')
//                 .attr('cx', d => x(d.label) + x.bandwidth() / 2)
//                 .attr('cy', d => y(d.value))
//                 .attr('r', 6)
//                 .attr('fill', 'orange')
//                 .on('mouseover', showTooltip)
//                 .on('mousemove', moveTooltip)
//                 .on('mouseout', hideTooltip);
//         }
//     }
// }
