import { LightningElement, api } from 'lwc';

export default class CsvExporter extends LightningElement {
    @api data = [];
    @api fileName;
    @api headers = [];

    handleExport() {
        console.log('Raw data received:', this.data);
        
        // Ensure data is an array
        const dataArray = Array.isArray(this.data) ? this.data : [this.data];
        
        if (!dataArray || dataArray.length === 0) {
            console.error('No data to export');
            return;
        }

        try {
            // Define default headers if not provided
            const defaultHeaders = [
                'Id',
                'GeneralLedgerName',
                'chart Of account',
                'Amount',
                'GeneralLedgerEntrydate',
                'OpeningBalance',
                'ClosingBalance',
                'JournalEntryId',
                'JournalEntryName',
                'DebitChartAccountName',
                'DebitCOA',
                'DebitAmount',
                'CreditChartAccountName',
                'CreditCOA',
                'creditAmount',
                'ChartOfAccountsBalance'
            ];

            const headers = this.headers?.length ? this.headers : defaultHeaders;
            console.log('Using headers:', headers);

            // Start with BOM for Excel
            let csvContent = '\ufeff';
            
            // Add headers
            csvContent += headers.join(',') + '\n';

            // Add data rows
            dataArray.forEach((row, index) => {
                const rowValues = headers.map(header => {
                    let value = row[header] ?? '';
                    // Handle special characters and quotes
                    value = String(value).replace(/"/g, '""');
                    // Wrap in quotes
                    return `"${value}"`;
                });
                csvContent += rowValues.join(',') + '\n';
                console.log(`Processed row ${index + 1}:`, rowValues);
            });

            // Create and trigger download
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8' });
            const blobUrl = window.URL.createObjectURL(blob);
            const downloadFilename = `${this.fileName || 'export'}.csv`;

            const downloadLink = document.createElement('a');
            downloadLink.href = blobUrl;
            downloadLink.download = downloadFilename;
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
            window.URL.revokeObjectURL(blobUrl);

        } catch (error) {
            console.error('Export failed:', error);
            console.error('Data that caused error:', this.data);
        }
    }
}
