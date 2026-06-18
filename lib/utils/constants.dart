const Map<String, String> docPrefixes = {
  'opening_balance': 'رصيد-اف',
  'production_receipt': 'وارد',
  'sales_issue': 'صادر',
  'loss': 'تالف',
  'adjustment_increase': 'تسوية-زيادة',
  'adjustment_decrease': 'تسوية-نقص',
  'reversal': 'عكس',
};

int getMovementEffect(String docType) {
  switch (docType) {
    case 'opening_balance':
    case 'production_receipt':
    case 'adjustment_increase':
    case 'reversal':
      return 1;
    case 'sales_issue':
    case 'loss':
    case 'adjustment_decrease':
      return -1;
    default:
      return 0;
  }
}

const Map<String, String> docTypeLabels = {
  'opening_balance': 'رصيد افتتاحي',
  'production_receipt': 'الواردات',
  'sales_issue': 'الصادرات',
  'loss': 'التالف والفاقد',
  'adjustment_increase': 'تسوية زيادة',
  'adjustment_decrease': 'تسوية نقص',
  'reversal': 'عكس وصل',
};

const Map<String, Map<String, String>> typeColors = {
  'production_receipt': {'bg': '#dcfce7', 'text': '#166534'},
  'sales_issue': {'bg': '#fff7ed', 'text': '#9a3412'},
  'loss': {'bg': '#fefce8', 'text': '#854d0e'},
  'adjustment_increase': {'bg': '#f1f5f9', 'text': '#475569'},
  'adjustment_decrease': {'bg': '#f1f5f9', 'text': '#475569'},
  'opening_balance': {'bg': '#e0f2fe', 'text': '#075985'},
  'reversal': {'bg': '#fce4ec', 'text': '#b91c1c'},
};

const List<String> monthsAr = [
  'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

const validDocTypes = [
  'opening_balance',
  'production_receipt',
  'sales_issue',
  'loss',
  'adjustment_increase',
  'adjustment_decrease',
  'reversal',
];
