import { LightningElement, wire } from 'lwc';
import getCurrentYearHolidays from '@salesforce/apex/HolidayController.getCurrentYearHolidays';

export default class HolidayCard extends LightningElement {

    holidays = [];
    currentIndex = 0;
    isModalOpen = false;
    currentYear = new Date().getFullYear();

    /* ================= APEX ================= */
    @wire(getCurrentYearHolidays)
    wiredHolidays({ data, error }) {
        if (data) {
            this.holidays = data.map(h => ({
                ...h,
                themeClass: this.getMonthTheme(h.month),
                rowClass: this.getMonthRowClass(h.month)
            }));
            this.setDefaultHoliday();
        } else if (error) {
            console.error(error);
        }
    }

    /* ================= DEFAULT HOLIDAY ================= */
    setDefaultHoliday() {
        const today = new Date();
        const idx = this.holidays.findIndex(
            h => new Date(h.holidayDate) >= today
        );
        this.currentIndex = idx >= 0 ? idx : this.holidays.length - 1;
    }

    get currentHoliday() {
        return this.holidays[this.currentIndex] || {};
    }

    get yearHolidays() {
        return this.holidays;
    }

    /* ================= NAV ================= */
    get showLeftArrow() {
        return this.currentIndex > 0;
    }

    get showRightArrow() {
        return this.currentIndex < this.holidays.length - 1;
    }

    showPrevious() {
        if (this.currentIndex > 0) this.currentIndex--;
    }

    showNext() {
        if (this.currentIndex < this.holidays.length - 1) this.currentIndex++;
    }

    /* ================= THEME ================= */
    get holidayContainerClass() {
        return `holiday-container ${this.currentHoliday.themeClass || 'theme-default'}`;
    }

    getMonthTheme(month) {
        switch (month) {
            case 'JAN': return 'theme-jan';
            case 'FEB': return 'theme-feb';
            case 'MAR': return 'theme-mar';
            case 'APR': return 'theme-apr';
            case 'JUN': return 'theme-jun';
            case 'JUL': return 'theme-jul';
            case 'AUG': return 'theme-aug';
            case 'OCT': return 'theme-oct';
            case 'NOV': return 'theme-nov';
            case 'DEC': return 'theme-dec';
            default: return 'theme-default';
        }
    }

    getMonthRowClass(month) {
        switch (month) {
            case 'JAN': return 'row-jan';
            case 'FEB': return 'row-feb';
            case 'MAR': return 'row-mar';
            case 'APR': return 'row-apr';
            case 'JUN': return 'row-jun';
            case 'JUL': return 'row-jul';
            case 'AUG': return 'row-aug';
            case 'OCT': return 'row-oct';
            case 'NOV': return 'row-nov';
            case 'DEC': return 'row-dec';
            default: return 'row-default';
        }
    }

    /* ================= MODAL ================= */
    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }
}