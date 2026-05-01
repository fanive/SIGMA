// ignore_for_file: avoid_print, unused_element, unused_import
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static final StripeService instance = StripeService._();
  StripeService._();

  /// Create a payment intent on your backend
  /// This is a simulation: in a real app, you would call your server
  Future<Map<String, dynamic>?> _createPaymentIntent(String amount, String currency) async {
    try {
      // In a real production app, this call goes to your Node.js/Python/Go backend
      // which uses the Stripe Secret Key to create an intent.
      
      // For demonstration, we'll return a mock response format 
      // but note that without a real clientSecret from Stripe, 
      // the PaymentSheet won't actually open in a real build.
      
      /*
      final body = {
        'amount': amount,
        'currency': currency,
        'payment_method_types[]': 'card'
      };

      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET_KEY']}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
      );
      return jsonDecode(response.body);
      */
      
      return null; // Mocking failure here because we don't have a backend URL
    } catch (err) {
      print('Error creating payment intent: $err');
      return null;
    }
  }

  Future<bool> makePayment({
    required BuildContext context,
    required double amount,
    required String tierLabel,
  }) async {
    try {
      // 1. Create Payment Intent (Simulated)
      // Map<String, dynamic>? paymentIntentData = await _createPaymentIntent(
      //   (amount * 100).toInt().toString(), 
      //   'USD'
      // );

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: const SetupPaymentSheetParameters(
          paymentIntentClientSecret: 'pi_mock_secret_xxxx', // Needs real secret from backend
          style: ThemeMode.dark,
          merchantDisplayName: 'SIGMA INTELLIGENCE',
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            testEnv: true,
          ),
          applePay: PaymentSheetApplePay(
            merchantCountryCode: 'US',
          ),
        ),
      );

      // 3. Display Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      if (e is StripeException) {
        print('Stripe Error: ${e.error.localizedMessage}');
      } else {
        print('Error: $e');
      }
      // Return false if cancelled or error
      return false;
    }
  }
}
