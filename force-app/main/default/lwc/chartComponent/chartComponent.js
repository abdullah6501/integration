import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import D3js from '@salesforce/resourceUrl/D3js';

export default class ChartComponent extends LightningElement {
    @api xAxis;
    @api yAxis;
    @api width;
    @api height;
    @api barColor;
    @api labelOrientation;

    _chartType;
    _chartData = [];
    _d3Loaded = false;

    @api
    set chartData(value) {
        this._chartData = value;
        if (this._d3Loaded && this._chartData.length) {
            this.renderChart();
        }
    }

    get chartData() {
        return this._chartData;
    }

    @api
    set chartType(value) {
        this._chartType = value;
        if (this._d3Loaded && this._chartData.length) {
            this.renderChart();
        }
    }

    get chartType() {
        return this._chartType;
    }

    renderedCallback() {
        if (this._d3Loaded) return;

        loadScript(this, D3js)
            .then(() => {
                this._d3Loaded = true;
                if (this._chartData.length) {
                    this.renderChart();
                }
            })
            .catch(error => {
                console.error('D3.js failed to load', error);
            });
    }

    renderChart() {
        const container = this.template.querySelector('.chart-container');
        const tooltip = d3.select(this.template.querySelector('.tooltip'));
        container.innerHTML = '';

        const margin = { top: 20, right: 30, bottom: 50, left: 50 };
        const chartWidth = this.width - margin.left - margin.right;
        const chartHeight = this.height - margin.top - margin.bottom;

        const svg = d3.select(container)
            .append('svg')
            .attr('width', this.width)
            .attr('height', this.height);

        const g = svg.append('g')
            .attr('transform', `translate(${margin.left},${margin.top})`);

        const colorScale = d3.scaleOrdinal()
            .domain(this._chartData.map(d => d[this.xAxis]))
            .range(d3.schemeCategory10);

        const x = d3.scaleBand()
            .domain(this._chartData.map(d => d[this.xAxis]))
            .range([0, chartWidth])
            .padding(0.5);

        const y = d3.scaleLinear()
            .domain([0, d3.max(this._chartData, d => d[this.yAxis])])
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

        if (this._chartType === 'bar') {
            g.selectAll('.bar')
                .data(this._chartData)
                .enter()
                .append('rect')
                .attr('class', 'bar')
                .attr('x', d => x(d[this.xAxis]))
                .attr('y', d => y(d[this.yAxis]))
                .attr('width', x.bandwidth())
                .attr('height', d => chartHeight - y(d[this.yAxis]))
                .attr('fill', this.barColor)
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this._chartType === 'line') {
            const line = d3.line()
                .x(d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .y(d => y(d[this.yAxis]));

            g.append('path')
                .datum(this._chartData)
                .attr('fill', 'none')
                .attr('stroke', this.barColor) 
                .attr('stroke-width', 2)
                .attr('d', line);

            g.selectAll('circle')
                .data(this._chartData)
                .enter()
                .append('circle')
                .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .attr('cy', d => y(d[this.yAxis]))
                .attr('r', 5)
                .attr('fill', this.barColor)
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this._chartType === 'pie') {
            container.innerHTML = '';

            const radius = Math.min(chartWidth, chartHeight) / 2;
            const svgPie = d3.select(container)
                .append('svg')
                .attr('width', this.width)
                .attr('height', this.height)
                .append('g')
                .attr('transform', `translate(${this.width / 2}, ${this.height / 2})`);

            const color = d3.scaleOrdinal(d3.schemeCategory10);

            const pie = d3.pie().value(d => d[this.yAxis]);
            const arc = d3.arc().innerRadius(0).outerRadius(radius);

            const arcs = svgPie.selectAll('arc')
                .data(pie(this._chartData))
                .enter()
                .append('g');

            arcs.append('path')
                .attr('d', arc)
                .attr('fill', d => color(d.data[this.xAxis]))
                .on('mouseover', (event, d) => showTooltip(event, d.data))
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        } else if (this._chartType === 'scatter') {
            g.selectAll('circle')
                .data(this._chartData)
                .enter()
                .append('circle')
                .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                .attr('cy', d => y(d[this.yAxis]))
                .attr('r', 6)
                .attr('fill', this.barColor)
                .on('mouseover', showTooltip)
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        }

        const xAxisGroup = g.append('g')
            .attr('transform', `translate(0, ${chartHeight})`)
            .call(d3.axisBottom(x));

        if (this.labelOrientation === 'horizontal') {
            xAxisGroup.selectAll("text")
                .attr("text-anchor", "middle")
                .attr("transform", "rotate(0)");
        } else if (this.labelOrientation === 'angled') {
            xAxisGroup.selectAll("text")
                .attr("text-anchor", "end")
                .attr("transform", "rotate(-45)")
                .attr("dx", "-0.8em")
                .attr("dy", "0.15em");
        } else if (this.labelOrientation === 'vertical') {
            xAxisGroup.selectAll("text")
                .attr("text-anchor", "end")
                .attr("transform", "rotate(-90)")
                .attr("dx", "-1.2em")
                .attr("dy", "-0.5em");
        }


        g.append('g').call(d3.axisLeft(y));

    }
}