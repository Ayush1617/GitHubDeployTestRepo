public with sharing class LetterPdfController {
    public String htmlContent { get; set; }

    public LetterPdfController() {
        String encoded = ApexPages.currentPage().getParameters().get('html');
        if (encoded != null) {
            // DECODE HERE
            htmlContent = EncodingUtil.urlDecode(encoded, 'UTF-8');
        } else {
            htmlContent = 'No content received.';
        }
    }
}