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
    @api compareFields = [];
    @api comparisonColors = {};
    @api startDate;
    @api endDate;

    _chartType;
    _chartData = [];
    _d3Loaded = false;

    @api
    set chartData(value) {
        this._chartData = value;
        console.log('chartdata---->', JSON.stringify(this._chartData));
        
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

        const margin = { top: 40, right: 30, bottom: 50, left: 100 };
        const chartWidth = this.width - margin.left - margin.right;
        const chartHeight = this.height - margin.top - margin.bottom;

        const svg = d3.select(container)
            .append('svg')
            .attr('width', this.width)
            .attr('height', this.height);

        const g = svg.append('g')
            .attr('transform', `translate(${margin.left},${margin.top})`);

        const colorScale = this.compareFields && this.compareFields.length > 0
            ? d3.scaleOrdinal()
                .domain(this.compareFields)
                .range(this.compareFields.map(field => this.comparisonColors[field] || '#888'))
            : d3.scaleOrdinal()
                .domain([this.yAxis])
                .range([this.barColor || '#888']);

        if (this._chartType === 'horizontal-bar') {
            this.renderHorizontalBarChart(g, svg, chartWidth, chartHeight, tooltip, margin);
            return;
        }
        const x = d3.scaleBand()
            .domain(this._chartData.map(d => d[this.xAxis]))
            .range([0, chartWidth])
            .padding(0.5);

        // const x = d3.scaleLinear()
        //         .domain([0, d3.max(this._chartData, d => +d[this.yAxis])])
        //         .range([0, chartWidth]);

        let yMax;
        if (this.compareFields && this.compareFields.length > 0) {
            yMax = d3.max(this._chartData, d => d3.max(this.compareFields, key => +d[key]));
        } else {
            yMax = d3.max(this._chartData, d => +d[this.yAxis]);
        }
        
        // const y = d3.scaleBand()
        //     .domain(this._chartData.map(d => d[this.xAxis]))
        //     .range([0, chartHeight])
        //     .padding(0.2);        
        
        const y = d3.scaleLinear()
            .domain([0, yMax])
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
            if (this.compareFields && this.compareFields.length > 0) {
                console.log('enter bar compare');
                console.log(this.compareFields.length);
                
                const x0 = d3.scaleBand()
                    .domain(this._chartData.map(d => d[this.xAxis]))
                    .range([0, chartWidth])
                    .padding(0.2);
        
                const x1 = d3.scaleBand()
                    .domain(this.compareFields)
                    .range([0, x0.bandwidth()])
                    .padding(0.05);
        
                const colorScale = d3.scaleOrdinal()
                    .domain(this.compareFields)
                    .range(this.compareFields.map(field => this.comparisonColors[field] || '#888'));
        
                g.append('g')
                    .selectAll('g')
                    .data(this._chartData)
                    .enter()
                    .append('g')
                    .attr('transform', d => `translate(${x0(d[this.xAxis])},0)`)
                    .selectAll('rect')
                    .data(d => this.compareFields.map(key => ({
                        key,
                        value: d[key],
                        label: d[this.xAxis]
                    })))
                    .enter()
                    .append('rect')
                    .attr('x', d => x1(d.key))
                    .attr('y', d => y(d.value))
                    .attr('width', x1.bandwidth())
                    .attr('height', d => chartHeight - y(d.value))
                    .attr('fill', d => colorScale(d.key))
                    .on('mouseover', (event, d) => {
                        tooltip
                            .style('display', 'block')
                            .text(`${d.label} (${d.key}): ₹${d.value}`);
                    })
                    .on('mousemove', moveTooltip)
                    .on('mouseout', hideTooltip);
        
            } else {
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
            }
        } else if (this._chartType === 'line') {
            if (this.compareFields && this.compareFields.length > 0) {
                this.compareFields.forEach(field => {
                    const line = d3.line()
                        .x(d => x(d[this.xAxis]) + x.bandwidth() / 2)
                        .y(d => y(d[field]));
        
                    g.append('path')
                        .datum(this._chartData)
                        .attr('fill', 'none')
                        .attr('stroke', this.comparisonColors[field] || '#888')
                        .attr('stroke-width', 2)
                        .attr('d', line);
        
                    g.selectAll(`.dot-${field}`)
                        .data(this._chartData)
                        .enter()
                        .append('circle')
                        .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                        .attr('cy', d => y(d[field]))
                        .attr('r', 4)
                        .attr('fill', this.comparisonColors[field] || '#888')
                        .on('mouseover', (event, d) => {
                            tooltip
                                .style('display', 'block')
                                .text(`${d[this.xAxis]} (${field}): ₹${d[field]}`);
                        })
                        .on('mousemove', moveTooltip)
                        .on('mouseout', hideTooltip);
                });
            } else {
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
                    .attr('r', 4)
                    .attr('fill', this.barColor)
                    .on('mouseover', showTooltip)
                    .on('mousemove', moveTooltip)
                    .on('mouseout', hideTooltip);
            }
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
            if (this.compareFields && this.compareFields.length > 0) {
                this.compareFields.forEach(field => {
                    g.selectAll(`.scatter-dot-${field}`)
                        .data(this._chartData)
                        .enter()
                        .append('circle')
                        .attr('cx', d => x(d[this.xAxis]) + x.bandwidth() / 2)
                        .attr('cy', d => y(d[field]))
                        .attr('r', 5)
                        .attr('fill', this.comparisonColors[field] || '#888')
                        .on('mouseover', (event, d) => {
                            tooltip
                                .style('display', 'block')
                                .text(`${d[this.xAxis]} (${field}): ₹${d[field]}`);
                        })
                        .on('mousemove', moveTooltip)
                        .on('mouseout', hideTooltip);
                });
            } else {
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
            }
        } else if (this._chartType === 'donut') {
            container.innerHTML = '';
        
            const radius = Math.min(chartWidth, chartHeight) / 2;
            const innerRadius = radius * 0.5;
        
            const svgDonut = d3.select(container)
                .append('svg')
                .attr('width', this.width)
                .attr('height', this.height)
                .append('g')
                .attr('transform', `translate(${this.width / 2}, ${this.height / 2})`);
        
            const color = d3.scaleOrdinal(d3.schemeCategory10);
        
            const pie = d3.pie().value(d => d[this.yAxis]);
            const arc = d3.arc().innerRadius(innerRadius).outerRadius(radius);
        
            const arcs = svgDonut.selectAll('arc')
                .data(pie(this._chartData))
                .enter()
                .append('g');
        
            arcs.append('path')
                .attr('d', arc)
                .attr('fill', d => color(d.data[this.xAxis]))
                .on('mouseover', (event, d) => showTooltip(event, d.data))
                .on('mousemove', moveTooltip)
                .on('mouseout', hideTooltip);
        
            arcs.append('text')
                .attr('transform', d => `translate(${arc.centroid(d)})`)
                .attr('text-anchor', 'middle')
                .attr('font-size', '10px')
                .text(d => d.data[this.xAxis]);
        } else if (this._chartType === 'treemap') {
            container.innerHTML = '';
        
            const svgTree = d3.select(container)
                .append('svg')
                .attr('width', this.width)
                .attr('height', this.height)
                .append('g')
                .attr('transform', `translate(0, 0)`);
        
            const color = d3.scaleOrdinal(d3.schemeCategory10);
        
            // Convert flat data into hierarchy format
            const root = d3.hierarchy({
                children: this._chartData
            }).sum(d => d[this.yAxis]);
        
            d3.treemap()
                .size([this.width, this.height])
                .padding(1)(root);
        
            const nodes = svgTree.selectAll('g')
                .data(root.leaves())
                .enter()
                .append('g')
                .attr('transform', d => `translate(${d.x0}, ${d.y0})`);
        
            const showTreemapTooltip = (event, d) => {
                const container = this.template.querySelector('.chart-container');
                const containerRect = container.getBoundingClientRect();
                const mouseX = event.clientX - containerRect.left;
                const mouseY = event.clientY - containerRect.top;
                
                tooltip
                    .style('display', 'block')
                    .html(`
                        <div style="font-weight: bold;">${d.data[this.xAxis]}</div>
                        <div>Value: ${d.data[this.yAxis]}</div>
                        <div>Percentage: ${((d.data[this.yAxis] / d3.sum(this._chartData, item => item[this.yAxis])) * 100).toFixed(1)}%</div>
                    `)
                    .style('left', (mouseX + 10) + 'px')
                    .style('top', (mouseY - 10) + 'px')
                    .style('background', 'rgba(0, 0, 0, 0.8)')
                    .style('color', 'white')
                    .style('padding', '8px')
                    .style('border-radius', '4px')
                    .style('font-size', '12px')
                    .style('box-shadow', '0 2px 4px rgba(0,0,0,0.2)')
                    .style('z-index', '1000')
                    .style('pointer-events', 'none');
            };
        
            const moveTreemapTooltip = (event) => {
                const container = this.template.querySelector('.chart-container');
                const containerRect = container.getBoundingClientRect();
                const mouseX = event.clientX - containerRect.left;
                const mouseY = event.clientY - containerRect.top;
                
                tooltip
                    .style('left', (mouseX + 10) + 'px')
                    .style('top', (mouseY - 10) + 'px');
            };
        
            const hideTreemapTooltip = () => {
                tooltip.style('display', 'none');
            };
        
            nodes.append('rect')
                .attr('width', d => d.x1 - d.x0)
                .attr('height', d => d.y1 - d.y0)
                .attr('fill', d => color(d.data[this.xAxis]))
                .attr('stroke', '#fff')
                .attr('stroke-width', 1)
                .style('cursor', 'pointer')
                .on('mouseover', showTreemapTooltip)
                .on('mousemove', moveTreemapTooltip)
                .on('mouseout', hideTreemapTooltip);
        
            nodes.append('text')
                .attr('x', d => Math.max(5, (d.x1 - d.x0) * 0.05))
                .attr('y', d => Math.max(15, (d.y1 - d.y0) * 0.15))
                .text(d => {
                    const width = d.x1 - d.x0;
                    const height = d.y1 - d.y0;
                    const text = d.data[this.xAxis];
                    
                    if (width > 50 && height > 20) {
                        return text.length > 15 ? text.substring(0, 12) + '...' : text;
                    }
                    return '';
                })
                .attr('font-size', d => {
                    const width = d.x1 - d.x0;
                    const height = d.y1 - d.y0;
                    
                    if (width > 100 && height > 40) return '12px';
                    if (width > 60 && height > 30) return '10px';
                    return '8px';
                })
                .attr('fill', 'white')
                .attr('font-weight', 'bold')
                .attr('text-shadow', '1px 1px 2px rgba(0,0,0,0.7)')
                .attr('pointer-events', 'none')
                .style('user-select', 'none');
        } 
        else if (this._chartType === 'gantt') {
            // const effectiveStartDate = this.startDate ? new Date(this.startDate) : new Date(2025, 0, 1);
            // const effectiveEndDate = this.endDate ? new Date(this.endDate) : new Date(2025, 11, 1);
            const effectiveStartDate = new Date(this.startDate);
            const effectiveEndDate = new Date(this.endDate);
            const today = new Date();

            svg.append('defs')
                .append('clipPath')
                .attr('id', 'clip')
                .append('rect')
                .attr('width', chartWidth)
                .attr('height', chartHeight);

            const x = d3.scaleTime()
                .domain([effectiveStartDate, effectiveEndDate])
                .range([0, chartWidth]);

            const y = d3.scaleBand()
                .domain(this._chartData.map(d => d.task))
                .range([0, chartHeight])
                .padding(0.2);

            const xAxis = d3.axisTop(x).tickFormat(d3.timeFormat('%b %Y'));
            const yAxis = d3.axisLeft(y);

            const xAxisGroup = svg.append('g')
                .attr('transform', `translate(${margin.left},${margin.top})`)
                .call(xAxis);

            const yAxisGroup = svg.append('g')
                .attr('transform', `translate(${margin.left},${margin.top})`)
                .call(yAxis);

            const chartGroup = svg.append('g')
                .attr('transform', `translate(${margin.left},${margin.top})`)
                .attr('clip-path', 'url(#clip)');

            const taskGroup = chartGroup.append('g');

            taskGroup.selectAll('rect')
                .data(this._chartData)
                .enter()
                .append('rect')
                .attr('x', d => x(new Date(d.start)))
                .attr('y', d => y(d.task))
                .attr('width', d => x(new Date(d.endDate)) - x(new Date(d.start)))
                .attr('height', y.bandwidth())
                .attr('fill', d => d.color || 'steelblue');

            chartGroup.append('line')
                .attr('x1', x(today))
                .attr('x2', x(today))
                .attr('y1', 0)
                .attr('y2', chartHeight)
                .attr('stroke', 'green')
                .attr('stroke-width', 2)
                .attr('stroke-dasharray', '5,5');

            const zoom = d3.zoom()
                .scaleExtent([0.5, 5])
                .translateExtent([[0, 0], [this.width, this.height]])
                .on('zoom', zoomed);

            svg.call(zoom);

            function getDynamicTickFormat(scale) {
                const range = scale.domain();
                const diff = (range[1] - range[0]) / (1000 * 60 * 60 * 24);
            
                if (diff > 60) {
                    return d3.timeFormat('%b %Y');
                } else if (diff > 10) {
                    return d3.timeFormat('%d %b'); 
                } else {
                    return d3.timeFormat('%d %b %H:%M'); 
                }
            }
            
            function zoomed(event) {
                const transform = event.transform;
                const newX = transform.rescaleX(x);
                const newTickFormat = getDynamicTickFormat(newX);
                xAxisGroup.call(xAxis.scale(newX).tickFormat(newTickFormat));

                taskGroup.selectAll('rect')
                    .attr('x', d => newX(new Date(d.start)))
                    .attr('width', d => newX(new Date(d.endDate)) - newX(new Date(d.start)));

                chartGroup.selectAll('line')
                    .attr('x1', newX(today))
                    .attr('x2', newX(today));
            }
            return;
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

        // ===== LEGEND SECTION =====
        if (this.compareFields && this.compareFields.length > 0) {
            const legend = svg.append('g')
                .attr('class', 'legend')
                .attr('transform', `translate(${this.width / 2}, ${this.height - 10})`)
                .attr('text-anchor', 'middle');

            const legendSpacing = 100; // spacing between legend items
            console.log('hiii--->');
            
            const legendGroup = legend.selectAll('g')
                .data(this.compareFields)
                .enter()
                .append('g')
                .attr('transform', (d, i) => `translate(${(i - (this.compareFields.length - 1) / 2) * legendSpacing}, 0)`);

                legendGroup.append('rect')
                    .attr('x', -15)
                    .attr('y', -10)
                    .attr('width', 20)
                    .attr('height', 20)
                    .attr('fill', d => this.comparisonColors[d] || '#888');
                
                legendGroup.append('text')
                    .attr('x', 35) 
                    .attr('y', 1)
                    .text(d => d)
                    .style('font-size', '12px')
                    .style('alignment-baseline', 'middle');
        }
    }

    renderHorizontalBarChart(g, svg, chartWidth, chartHeight, tooltip, margin) {
        const container = this.template.querySelector('.chart-container');
        
        const y = d3.scaleBand()
            .domain(this.compareFields)
            .range([0, chartHeight])
            .padding(0.1);
    
        let xMax = 0;
        if (this.compareFields && this.compareFields.length > 0) {
            xMax = d3.max(this._chartData, d => d3.max(this.compareFields, key => +d[key] || 0));
        }
        
        if (xMax === 0) {
            xMax = 1;
        }
        
        const x = d3.scaleLinear()
            .domain([0, xMax])
            .range([0, chartWidth]);
    
        const colorScale = d3.scaleOrdinal()
            .domain(this.compareFields)
            .range(this.compareFields.map(field => this.comparisonColors[field] || '#888'));
    
        const formatValue = (value) => {
            if (value >= 1000000) {
                return `${(value / 1000000).toFixed(1)}M`;
            } else if (value >= 1000) {
                return `${(value / 1000).toFixed(0)}K`;
            } else {
                return `${value}`;
            }
        };
    
        const formatAxisTick = (value) => {
            if (value >= 1000000) {
                return `${(value / 1000000).toFixed(1)}M`;
            } else if (value >= 1000) {
                return `${(value / 1000).toFixed(0)}K`;
            } else {
                return `${value}`;
            }
        };
    
        this.compareFields.forEach(field => {
            const data = this._chartData[0]; 
            const value = data[field] || 0;
            
            if (value > 0) {
                g.append('rect')
                    .attr('x', 0)
                    .attr('y', y(field))
                    .attr('width', x(value))
                    .attr('height', y.bandwidth())
                    .attr('fill', colorScale(field))
                    .on('mouseover', (event, d) => {
                        const rect = event.target.getBoundingClientRect();
                        const containerRect = container.getBoundingClientRect();
                        
                        tooltip
                            .style('display', 'block')
                            .text(`${field}: ${formatValue(value)}`)
                            .style('left', (rect.left - containerRect.left + rect.width/2) + 'px')
                            .style('top', (rect.top - containerRect.top - 30) + 'px')
                            .style('transform', 'translateX(-50%)');
                    })
                    .on('mousemove', (event) => {
                    })
                    .on('mouseout', () => tooltip.style('display', 'none'));
            }
        });
    
        g.append('g')
            .attr('transform', `translate(0, 0)`)
            .call(d3.axisTop(x)
                .tickFormat(formatAxisTick)
                .ticks(5));
    
        g.append('g')
            .call(d3.axisLeft(y));
    
        g.selectAll('.grid-line')
            .data(x.ticks(5))
            .enter()
            .append('line')
            .attr('class', 'grid-line')
            .attr('x1', d => x(d))
            .attr('x2', d => x(d))
            .attr('y1', 0)
            .attr('y2', chartHeight)
            .attr('stroke', '#e0e0e0')
            .attr('stroke-dasharray', '2,2');
    }
}