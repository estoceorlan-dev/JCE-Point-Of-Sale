class ReportFilterOption {
  const ReportFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ReportFilterOptions {
  const ReportFilterOptions({
    required this.products,
    required this.categories,
    required this.users,
  });

  final List<ReportFilterOption> products;
  final List<ReportFilterOption> categories;
  final List<ReportFilterOption> users;
}
