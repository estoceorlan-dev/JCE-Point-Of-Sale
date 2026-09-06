export 'receipt_pdf_saver_unsupported.dart'
    if (dart.library.io) 'receipt_pdf_saver_io.dart'
    if (dart.library.html) 'receipt_pdf_saver_web.dart';
