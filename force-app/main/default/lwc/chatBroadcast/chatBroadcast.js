import { LightningElement, track } from 'lwc';

export default class ChatBroadcast extends LightningElement {
    @track selectedTemplate = '';
    @track tableData;
    @track tableColumns;

    templateOptions = [
        { label: 'Welcome Template', value: 'welcome' },
        { label: 'Promotion Template', value: 'promotion' }
        // Add more templates here
    ];

    handleNewChat() {
        this.selectedTemplate = '';
        this.tableData = null;
        this.tableColumns = null;
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
    }

    handleFileUpload(event) {
        if (event.target.files.length > 0) {
            let file = event.target.files[0];
            this.readFile(file);
        }
    }

    readFile(file) {
        let reader = new FileReader();
        reader.onload = () => {
            let csv = reader.result;
            this.parseCSV(csv);
        };
        reader.readAsText(file);
    }

    parseCSV(csv) {
        let allRows = csv.split(/\r\n|\n/);
        let headers = allRows[0].split(',');

        this.tableColumns = headers.map(header => ({
            label: header,
            fieldName: header.trim(),
            type: 'text'
        }));

        let data = [];
        for (let i = 1; i < allRows.length; i++) {
            if (allRows[i].trim() !== '') {
                let row = allRows[i].split(',');
                let rowData = {};
                headers.forEach((header, index) => {
                    rowData[header.trim()] = row[index];
                });
                rowData.id = i; // Unique key
                data.push(rowData);
            }
        }
        this.tableData = data;
    }
}
