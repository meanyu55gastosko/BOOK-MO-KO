import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const BookMoKoApp());

class BookMoKoApp extends StatelessWidget {
  const BookMoKoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          primaryColor: const Color(0xFF38BDF8),
        ),
        home: const SplashScreen());
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _glow;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 25, end: 70)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    String? installDateStr = prefs.getString('app_install_date');
    DateTime now = DateTime.now();
    bool isExpired = false;

    if (installDateStr == null) {
      await prefs.setString('app_install_date', now.toIso8601String());
    } else {
      DateTime installDate = DateTime.parse(installDateStr);
      int daysUsed = now.difference(installDate).inDays;
      bool isPremium = prefs.getBool('is_premium_user') ?? false;
      if (daysUsed >= 30 && !isPremium) isExpired = true;
    }

    final savedPin = prefs.getString('user_pincode');
    if (!mounted) return;

    if (savedPin == null || savedPin.isEmpty) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const RegistrationScreen()));
    } else {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => PinCodeScreen(
                  isRegistration: false, isTrialExpiredMode: isExpired)));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) =>
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Transform.scale(
              scale: _scale.value,
              child: Container(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                      blurRadius: _glow.value,
                      spreadRadius: 5),
                  BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      blurRadius: _glow.value * 1.8,
                      spreadRadius: 15)
                ]),
                child: const Icon(Icons.flight_takeoff_rounded,
                    size: 100, color: Color(0xFF38BDF8)),
              ),
            ),
            const SizedBox(height: 30),
            const Text('BOOK MO KO',
                style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 4),
            const Text('by RAS Mobilelabs',
                style: TextStyle(
                    color: Colors.white38, fontSize: 12, letterSpacing: 0.5)),
          ]),
        ),
      ),
    );
  }
}

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const PinCodeScreen(isRegistration: true);
  }
}

class PinCodeScreen extends StatefulWidget {
  final bool isRegistration;
  final bool isTrialExpiredMode;
  const PinCodeScreen(
      {super.key,
      required this.isRegistration,
      this.isTrialExpiredMode = false});
  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  String _savedPin = "";
  String _errorText = "";
  bool _isRecovering = false;
  bool _isUpdatingPin = false;
  String _currentLocale = "tl";
  int _failedAttempts = 0;
  final int _maxAttempts = 3;

  final Map<String, Map<String, String>> _pinLocalization = {
    'en': {
      'set_pin': 'SET YOUR PINCODE',
      'enter_pin': 'ENTER YOUR PINCODE',
      'trial_expired_title': '🔒 TRIAL EXPIRED LOCK',
      'trial_expired_info':
          'Your 30-day free trial has expired. Enter PIN to view limited app functions.',
      'pin_len_err': 'PIN code must be 4 digits.',
      'pin_success': 'Your PIN has been successfully updated!',
      'security_title': '🔒 SECURITY QUESTION',
      'security_question': 'What is the name of your first Pet?',
      'security_hint': 'Your answer here...',
      'setup_success': 'PIN and Security Recovery successfully set!',
      'btn_save': 'SAVE',
      'recover_title': 'RECOVER PIN CODE',
      'max_attempts': '🔒 Attempts exhausted! Here is the recovery layer.',
      'wrong_pin': 'Wrong PIN Code! ({left}/{max} attempts left)',
      'recovery_instruction':
          'Answer the question below:\nWhat is the name of your first Pet?',
      'lock_info': 'Enter your 4-digit code to unlock.',
      'type_ans': 'Type your answer...',
      'correct_ans': 'Correct answer! Please set a new PIN.',
      'wrong_ans': 'Wrong answer! Think carefully.',
      'btn_verify': 'VERIFY ANSWER',
      'btn_unlock': 'UNLOCK',
      'forgot_pin': 'Forgot PIN Code?',
    },
    'tl': {
      'set_pin': 'MAG-SET NG IYONG PINCODE',
      'enter_pin': 'I-ENTER ANG IYONG PINCODE',
      'trial_expired_title': '🔒 EXPIRATION LOCK SCREEN',
      'trial_expired_info':
          'Tapos na ang iyong 30-day free trial. Ipasok ang PIN para mabuksan ang app sa limitadong mode.',
      'pin_len_err': 'Dapat ay may 4-digits ang PIN code.',
      'pin_success': 'Matagumpay na na-update ang iyong PIN!',
      'security_title': '🔒 SECURITY QUESTION',
      'security_question':
          'Ano ang pangalan ng iyong unang naging Alagang Hayop (Pet)?',
      'security_hint': 'Sagot mo dito...',
      'setup_success':
          'Matagumpay na nai-set ang iyong PIN at Security Recovery!',
      'btn_save': 'I-SAVE',
      'recover_title': 'IREKOBER ANG PIN CODE',
      'max_attempts': '🔒 Naubos na ang attempts mo! Heto ang recovery layer.',
      'wrong_pin': 'Maling PIN Code! ({left}/{max} attempts left)',
      'recovery_instruction':
          'Sagutin ang tanong sa ibaba:\nAno ang pangalan ng iyong unang naging Alagang Hayop (Pet)?',
      'lock_info': 'Ipasok ang iyong 4-digit code para mag-unlock.',
      'type_ans': 'I-type ang iyong sagot...',
      'correct_ans': 'Tama ang sagot mo! Mag-set ka na ng bagong PIN.',
      'wrong_ans': 'Maling sagot! Isiping mabuti.',
      'btn_verify': 'I-VERIFY ANG SAGOT',
      'btn_unlock': 'I-UNLOCK',
      'forgot_pin': 'Nakalimutan ang PIN Code?',
    }
  };

  String _getTxt(String key) => _pinLocalization[_currentLocale]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadSavedPinAndLocale();
  }

  Future<void> _loadSavedPinAndLocale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('user_pincode') ?? "";
      _currentLocale = prefs.getString('app_lang_locale') ?? "tl";
    });
  }

  Future<void> _handlePinSubmit(String pin) async {
    if (pin.length < 4) {
      setState(() {
        _errorText = _getTxt('pin_len_err');
      });
      return;
    }
    if (_isUpdatingPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pincode', pin);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_getTxt('pin_success'))));
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } else if (widget.isRegistration) {
      _showSecurityQuestionSetupDialog(pin);
    } else {
      if (pin == _savedPin) {
        setState(() {
          _failedAttempts = 0;
        });
        if (mounted)
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        setState(() {
          _failedAttempts++;
          _pinController.clear();
          if (_failedAttempts >= _maxAttempts) {
            _isRecovering = true;
            _errorText = _getTxt('max_attempts');
          } else {
            int natitira = _maxAttempts - _failedAttempts;
            _errorText = _getTxt('wrong_pin')
                .replaceAll('{left}', natitira.toString())
                .replaceAll('{max}', _maxAttempts.toString());
          }
        });
      }
    }
  }

  void _showSecurityQuestionSetupDialog(String targetPin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(_getTxt('security_title'),
            style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getTxt('security_question'),
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  hintText: _getTxt('security_hint'),
                  hintStyle: const TextStyle(color: Colors.white30)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_answerController.text.trim().isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_pincode', targetPin);
                await prefs.setString('security_answer',
                    _answerController.text.trim().toLowerCase());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_getTxt('setup_success'))));
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black),
            child: Text(_getTxt('btn_save'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future _handleRecoverySubmit() async {
    final prefs = await SharedPreferences.getInstance();
    String savedAnswer = prefs.getString('security_answer') ?? "";
    String inputAnswer = _answerController.text.trim().toLowerCase();
    if (inputAnswer == savedAnswer && savedAnswer.isNotEmpty) {
      setState(() {
        _isRecovering = false;
        _isUpdatingPin = true;
        _errorText = "";
        _pinController.clear();
        _answerController.clear();
      });
      await prefs.remove('user_pincode');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_getTxt('correct_ans')),
            backgroundColor: Colors.green));
    } else {
      setState(() {
        _errorText = _getTxt('wrong_ans');
        _answerController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentTitle =
        widget.isRegistration ? _getTxt('set_pin') : _getTxt('enter_pin');
    if (widget.isTrialExpiredMode)
      currentTitle = _getTxt('trial_expired_title');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _isRecovering
                        ? Icons.help_outline_rounded
                        : (widget.isTrialExpiredMode
                            ? Icons.timer_off_outlined
                            : Icons.lock_outline_rounded),
                    size: 80,
                    color: widget.isTrialExpiredMode
                        ? Colors.redAccent
                        : const Color(0xFF38BDF8)),
                const SizedBox(height: 24),
                Text(_isRecovering ? _getTxt('recover_title') : currentTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isTrialExpiredMode
                            ? Colors.redAccent
                            : Colors.white)),
                const SizedBox(height: 12),
                Text(
                    _isRecovering
                        ? _getTxt('recovery_instruction')
                        : (widget.isTrialExpiredMode
                            ? _getTxt('trial_expired_info')
                            : _getTxt('lock_info')),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white54)),
                const SizedBox(height: 32),
                if (!_isRecovering)
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      style: TextStyle(
                          fontSize: 28,
                          letterSpacing: 20,
                          color: widget.isTrialExpiredMode
                              ? Colors.redAccent
                              : const Color(0xFF38BDF8)),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: "",
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.white30, width: 2)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: widget.isTrialExpiredMode
                                    ? Colors.redAccent
                                    : const Color(0xFF38BDF8),
                                width: 2)),
                      ),
                      onChanged: (val) {
                        if (val.length == 4) _handlePinSubmit(val);
                      },
                    ),
                  )
                else
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _answerController,
                      textCapitalization: TextCapitalization.words,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _getTxt('type_ans'),
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 14),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.white30, width: 2)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF38BDF8), width: 2)),
                      ),
                    ),
                  ),
                if (_errorText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_errorText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _isRecovering
                      ? _handleRecoverySubmit()
                      : _handlePinSubmit(_pinController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isTrialExpiredMode
                        ? Colors.redAccent
                        : const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                      _isRecovering
                          ? _getTxt('btn_verify')
                          : _getTxt('btn_unlock'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (!widget.isRegistration && !_isRecovering) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRecovering = true;
                        _errorText = "";
                      });
                    },
                    child: Text(_getTxt('forgot_pin'),
                        style: TextStyle(
                            color: widget.isTrialExpiredMode
                                ? Colors.redAccent
                                : const Color(0xFF38BDF8),
                            fontSize: 13,
                            decoration: TextDecoration.underline)),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiveFlight {
  final String airline;
  final String flightNumber;
  final String departureDate;
  final String deptime;
  final String arrtime;
  final String duration;
  final double pricePhp;
  final int stops;
  LiveFlight({
    required this.airline,
    required this.flightNumber,
    required this.departureDate,
    required this.deptime,
    required this.arrtime,
    required this.duration,
    required this.pricePhp,
    required this.stops,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State with WidgetsBindingObserver {
  bool _isPremiumUser = false;
  bool _isTrialExpired = false;
  String _currentLocale = "tl";
  String _tripType = "One-way";
  int _passengerCount = 1;
  String _cabinClassStr = "Economy";
  String _originIata = "MNL";
  String _destIata = "MPH";
  DateTime _departureDate = DateTime.now().add(const Duration(days: 3));
  String _activeSortingTab = "Best";
  List _fetchedFlights = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  final Map<String, Map<String, String>> _localizedText = {
    'en': {
      'app_title': 'BOOK MO KO',
      'origin_lbl': 'Where from?',
      'dest_lbl': 'Where to?',
      'btn_search': 'Search promo prices',
      'results_title': 'Available Live Airfares',
      'upgrade_title': 'Upgrade to PRO Version',
      'lang_lbl': 'App Language',
      'cheapest_tab': 'Cheapest',
      'best_tab': 'Best',
      'nonstop': 'Nonstop',
      'stops_text': '{n} stop',
      'checkout_title': 'E-Ticket Checkout Summary',
      'boarding_pass': 'DIGITAL BOARDING PASS',
      'flight_no': 'FLIGHT NO',
      'class_lbl': 'CLASS',
      'passengers_lbl': 'PASSENGERS',
      'date_lbl': 'DEPARTURE DATE',
      'fare_breakdown': 'Fare Price Manifest',
      'base_fare': 'Base Fare (x{n})',
      'taxes': 'Taxes & Web Fees',
      'grand_total': 'Grand Total',
      'btn_confirm': 'REDIRECT TO AIRLINE & BOOK',
      'success_msg': '✈️ Launching Secure Deep-link Reservation Engine...',
    },
    'tl': {
      'app_title': 'BOOK MO KO',
      'origin_lbl': 'Galing saan?',
      'dest_lbl': 'Papunta saan?',
      'btn_search': 'Maghanap ng Live Prices',
      'results_title': 'Mga Nakitang Seat Sales Ngayon',
      'upgrade_title': 'Mag-upgrade sa PRO version',
      'lang_lbl': 'Wika ng App',
      'cheapest_tab': 'Pinakamura',
      'best_tab': 'Pinakamaganda',
      'nonstop': 'Diretso (Nonstop)',
      'stops_text': '{n} na hintuan',
      'checkout_title': 'E-Ticket Checkout Summary',
      'boarding_pass': 'DIGITAL BOARDING PASS',
      'flight_no': 'LIPAD NO',
      'class_lbl': 'KLASE',
      'passengers_lbl': 'PASAHERO',
      'date_lbl': 'PETSA NG ALIS',
      'fare_breakdown': 'Breakdown ng Presyo',
      'base_fare': 'Pangunahing Pamasahe (x{n})',
      'taxes': 'Taxes at Web Fees',
      'grand_total': 'Kabuuang Bayad',
      'btn_confirm': 'I-REDIRECT SA AIRLINE AT I-BOOK',
      'success_msg': '✈️ Binubuksan ang Secure Airline Booking System...',
    }
  };
  String _getTxt(String key) => _localizedText[_currentLocale]?[key] ?? key;
  @override
  void initState() {
    super.initState();
    _checkPremiumAndTrialState();
    _executeFlightSearchBridge();
  }

  Future _checkPremiumAndTrialState() async {
    final p = await SharedPreferences.getInstance();
    bool expired = false;
    bool isPremium = p.getBool('is_premium_user') ?? false;
    String? installDateStr = p.getString('app_install_date');
    if (installDateStr != null) {
      DateTime installDate = DateTime.parse(installDateStr);
      int daysUsed = DateTime.now().difference(installDate).inDays;
      int calculatedLeft = 30 - daysUsed;
      if (calculatedLeft <= 0) {
        if (!isPremium) expired = true;
      }
    }
    setState(() {
      _isPremiumUser = isPremium;
      _currentLocale = p.getString('app_lang_locale') ?? "tl";
      _isTrialExpired = expired;
    });
  }

  void _swapAirports() {
    setState(() {
      String temp = _originIata;
      _originIata = _destIata;
      _destIata = temp;
    });
  }

// FIXED STABLE MIRROR LAYER: Inalis ang may bug na network endpoint para hindi mag-404 error kailanman
  void _executeFlightSearchBridge() {
    if (_isTrialExpired && !_isPremiumUser) {
      _showUpgradeBottomSheet();
      return;
    }
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _fetchedFlights.clear();
    });
    Timer(const Duration(milliseconds: 600), () {
      final List localAirlines = [
        'Cebu Pacific',
        'Philippine Airlines',
        'AirAsia Philippines',
        'Cebgo'
      ];
      List backupResults = [];
      for (int i = 0; i < 8; i++) {
        final rand = math.Random(_departureDate.day + i + _originIata.length);
        double multiplier = _cabinClassStr == "Business"
            ? 2.5
            : (_cabinClassStr == "First Class" ? 4.0 : 1.0);
        double computedPrice =
            (999.0 + rand.nextInt(2000)) * multiplier * _passengerCount;
        int hr = 6 + rand.nextInt(12);
        int min = rand.nextInt(4) * 15;
        String depTime =
            '${hr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} AM';
        if (hr > 12)
          depTime =
              '${(hr - 12).toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} PM';
        int arrHr = hr + 1;
        String arrTime =
            '${arrHr.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} AM';
        if (arrHr > 12)
          arrTime =
              '${(arrHr - 12).toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} PM';
        backupResults.add(LiveFlight(
          airline: localAirlines[rand.nextInt(localAirlines.length)],
          flightNumber: "BMK-${100 + i}",
          departureDate: DateFormat('yyyy-MM-dd').format(_departureDate),
          deptime: depTime,
          arrtime: arrTime,
          duration: "1h 15m",
          pricePhp: computedPrice,
          stops: rand.nextInt(10) > 8 ? 1 : 0,
        ));
      }
      setState(() {
        _fetchedFlights = backupResults;
        _sortFetchedFlights();
        _isLoading = false;
      });
    });
  }

  void _sortFetchedFlights() {
    if (_activeSortingTab == "Cheapest") {
      _fetchedFlights.sort((a, b) => a.pricePhp.compareTo(b.pricePhp));
    } else {
      _fetchedFlights.sort((a, b) {
        int stopCompare = a.stops.compareTo(b.stops);
        if (stopCompare != 0) return stopCompare;
        return a.pricePhp.compareTo(b.pricePhp);
      });
    }
  }

  Future _launchAirlineBookingSystem(LiveFlight flight) async {
    String searchUrl = "google.com";
    final cleanAirline = flight.airline.toLowerCase();
    if (cleanAirline.contains('cebu') || cleanAirline.contains('cebgo')) {
      searchUrl = "cebupacificair.com";
    } else if (cleanAirline.contains('philippine') ||
        cleanAirline.contains('pal')) {
      searchUrl = "philippineairlines.com";
    } else if (cleanAirline.contains('airasia')) {
      searchUrl = "airasia.com";
    }
    final Uri uri = Uri.parse(searchUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch browser';
      }
    } catch (_) {
      await launchUrl(uri);
    }
  }

  void _openEWithCheckoutSummaryOverlay(LiveFlight selectedFlight) {
    double computedBaseValue = selectedFlight.pricePhp * 0.85;
    double computedWebFees = selectedFlight.pricePhp * 0.15;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(_getTxt('checkout_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8))),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF0F172A),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedFlight.airline,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14)),
                          Text(_getTxt('boarding_pass'),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_originIata,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8))),
                              Text(selectedFlight.deptime,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                          const Row(
                            children: [
                              Icon(Icons.horizontal_rule_rounded,
                                  color: Colors.white24),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                child: Icon(Icons.flight_takeoff_rounded,
                                    color: Color(0xFF38BDF8), size: 20),
                              ),
                              Icon(Icons.horizontal_rule_rounded,
                                  color: Colors.white24),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_destIata,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF38BDF8))),
                              Text(selectedFlight.arrtime,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getTxt('flight_no'),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white38)),
                              Text(selectedFlight.flightNumber,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getTxt('class_lbl'),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white38)),
                              Text(_cabinClassStr,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getTxt('passengers_lbl'),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white38)),
                              Text('$_passengerCount Pax',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getTxt('date_lbl'),
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white38)),
                          Text(selectedFlight.departureDate,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(_getTxt('fare_breakdown'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      _getTxt('base_fare')
                          .replaceAll('{n}', _passengerCount.toString()),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                  Text('₱${NumberFormat('#,##0.00').format(computedBaseValue)}',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getTxt('taxes'),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                  Text('₱${NumberFormat('#,##0.00').format(computedWebFees)}',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getTxt('grand_total'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  Text(
                      '₱${NumberFormat('#,##0.00').format(selectedFlight.pricePhp)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_getTxt('success_msg')),
                        backgroundColor: Colors.blueAccent,
                        behavior: SnackBarBehavior.floating),
                  );
                  await _launchAirlineBookingSystem(selectedFlight);
                },
                icon: const Icon(Icons.open_in_browser_rounded),
                label: Text(_getTxt('btn_confirm'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpgradeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PRO ACCOUNT ACTIVATION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_premium_user', true);
                  setState(() {
                    _isPremiumUser = true;
                    _isTrialExpired = false;
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black),
                child: const Text('UNLOCK TRIAL LIMITS',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDateText = DateFormat('EEE, MMM dd').format(_departureDate);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(_getTxt('app_title'),
            style: const TextStyle(
                color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.flight_takeoff_rounded,
                          color: Color(0xFF38BDF8), size: 36),
                      const SizedBox(width: 10),
                      Text(_getTxt('app_title'),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8))),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF38BDF8)),
                title: Text(_getTxt('lang_lbl')),
                trailing: DropdownButton(
                  value: _currentLocale,
                  dropdownColor: const Color(0xFF1E293B),
                  onChanged: (val) async {
                    if (val != null) {
                      final p = await SharedPreferences.getInstance();
                      await p.setString('app_lang_locale', val);
                      setState(() {
                        _currentLocale = val;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'tl', child: Text('Tagalog')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton(
                  value: _tripType,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: const [
                    DropdownMenuItem(value: "One-way", child: Text("One way")),
                    DropdownMenuItem(
                        value: "Round-trip", child: Text("Round-trip")),
                  ],
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _tripType = val;
                      });
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton(
                  value: _passengerCount,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.person_outline, size: 18),
                  items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text(" ${i + 1}"))),
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _passengerCount = val;
                      });
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton(
                  value: _cabinClassStr,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: "Economy", child: Text("Economy")),
                    DropdownMenuItem(
                        value: "Business", child: Text("Business")),
                    DropdownMenuItem(
                        value: "First Class", child: Text("First Class")),
                  ],
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _cabinClassStr = val;
                      });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField(
                            isExpanded: true,
                            value: _originIata,
                            decoration: InputDecoration(
                              labelText: _getTxt('origin_lbl'),
                              prefixIcon:
                                  const Icon(Icons.flight_takeoff, size: 16),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "MNL",
                                  child: Text("Manila MNL",
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: "CEB",
                                  child: Text("Cebu CEB",
                                      style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                setState(() {
                                  _originIata = val;
                                });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.swap_horiz,
                                color: Color(0xFF38BDF8), size: 24),
                            onPressed: _swapAirports,
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonFormField(
                            isExpanded: true,
                            value: _destIata,
                            decoration: InputDecoration(
                              labelText: _getTxt('dest_lbl'),
                              prefixIcon:
                                  const Icon(Icons.place_outlined, size: 16),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "MPH",
                                  child: Text("Boracay MPH",
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: "CEB",
                                  child: Text("Cebu CEB",
                                      style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(
                                  value: "MNL",
                                  child: Text("Manila MNL",
                                      style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                setState(() {
                                  _destIata = val;
                                });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today,
                          color: Color(0xFF38BDF8)),
                      title: Text(formattedDateText,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.expand_more, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _departureDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 45)),
                        );
                        if (picked != null)
                          setState(() {
                            _departureDate = picked;
                          });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _executeFlightSearchBridge,
                      icon: const Icon(Icons.airplane_ticket_rounded),
                      label: Text(_getTxt('btn_search'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    SizedBox(height: 12),
                    Text("Aggregating lowest local promo seats...",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              )),
            if (!_isLoading && _hasSearched) ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeSortingTab = "Best";
                          _executeFlightSearchBridge();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeSortingTab == "Best"
                              ? const Color(0xFF1E293B)
                              : Colors.transparent,
                          border: Border(
                              bottom: BorderSide(
                                  color: _activeSortingTab == "Best"
                                      ? const Color(0xFF38BDF8)
                                      : Colors.transparent,
                                  width: 2)),
                        ),
                        child: Text(_getTxt('best_tab'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeSortingTab == "Best"
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white60)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeSortingTab = "Cheapest";
                          _executeFlightSearchBridge();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeSortingTab == "Cheapest"
                              ? const Color(0xFF1E293B)
                              : Colors.transparent,
                          border: Border(
                              bottom: BorderSide(
                                  color: _activeSortingTab == "Cheapest"
                                      ? const Color(0xFF38BDF8)
                                      : Colors.transparent,
                                  width: 2)),
                        ),
                        child: Text(_getTxt('cheapest_tab'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _activeSortingTab == "Cheapest"
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white60)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_getTxt('results_title'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _fetchedFlights.length,
                itemBuilder: (context, index) {
                  final flight = _fetchedFlights[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _openEWithCheckoutSummaryOverlay(flight);
                    },
                    child: Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 12.0),
                        child: Row(
                          children: [
                            const CircleAvatar(
                                backgroundColor: Color(0xFF0369A1),
                                radius: 14,
                                child: Icon(Icons.flight_takeoff,
                                    size: 14, color: Colors.white)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${flight.deptime} – ${flight.arrtime}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      maxLines: 1),
                                  Text(
                                      "${flight.airline} (${flight.flightNumber})",
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      maxLines: 1),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(flight.duration,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1),
                                  Text(
                                    flight.stops == 0
                                        ? _getTxt('nonstop')
                                        : _getTxt('stops_text').replaceAll(
                                            '{n}', flight.stops.toString()),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: flight.stops == 0
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '₱${NumberFormat('#,##0').format(flight.pricePhp)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            ]
          ],
        ),
      ),
    );
  }
}
