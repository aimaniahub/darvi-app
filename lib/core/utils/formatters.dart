import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static String money(double value, {String currency = 'INR'}) {
    final symbol = currency == 'INR' ? '\u20B9 ' : '$currency ';
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
      locale: 'en_IN',
    );
    return format.format(value);
  }

  static String shortDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  static String date(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }
}
