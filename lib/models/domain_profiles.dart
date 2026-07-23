class MarriageProfile {
  const MarriageProfile({
    required this.age,
    required this.gender,
    required this.seeking,
    required this.bio,
    required this.cityId,
    required this.photoCount,
    this.salaryBand,
    this.religion,
    this.nativeLanguage,
    this.maritalStatus,
    this.heightCm,
    this.education,
    this.occupation,
    this.diet,
    this.community,
  });
  final int age;
  final String gender;
  final String seeking;
  final String bio;
  final String cityId;
  final int photoCount;
  final String? salaryBand;
  final String? religion;
  final String? nativeLanguage;
  final String? maritalStatus;
  final int? heightCm;
  final String? education;
  final String? occupation;
  final String? diet;
  final String? community;

  static const genders = <String>['woman', 'man', 'other'];
  static const seekingOptions = <String>['woman', 'man', 'everyone'];

  /// Same bands the age → ageBand mapping writes on publish.
  static const ageBands = <String>[
    '18-24',
    '25-29',
    '30-34',
    '35-39',
    '40-49',
    '50+',
  ];
  static const salaryBands = <String>[
    'Prefer not to say',
    'Under ₹5L/year',
    '₹5–10L/year',
    '₹10–20L/year',
    '₹20–40L/year',
    '₹40L+/year',
  ];
  static const religions = <String>[
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Buddhist',
    'Jain',
    'Other',
  ];
  static const nativeLanguages = <String>[
    'Hindi',
    'English',
    'Marathi',
    'Tamil',
    'Telugu',
    'Kannada',
    'Bengali',
    'Gujarati',
    'Punjabi',
    'Malayalam',
  ];
  static const maritalStatuses = <String>[
    'Never married',
    'Divorced',
    'Widowed',
    'Separated',
  ];
  static const heightsCm = <int>[150, 155, 160, 165, 170, 175, 180, 185, 190];
  static const educationOptions = <String>[
    'School',
    'Diploma',
    'Graduate',
    'Postgraduate',
    'Doctorate',
  ];
  static const occupations = <String>[
    'Salaried',
    'Business',
    'Professional',
    'Government',
    'Student',
    'Homemaker',
    'Other',
  ];
  static const diets = <String>[
    'Vegetarian',
    'Non-vegetarian',
    'Eggetarian',
    'Vegan',
  ];

  String get ageBand => switch (age) {
    < 25 => ageBands[0],
    < 30 => ageBands[1],
    < 35 => ageBands[2],
    < 40 => ageBands[3],
    < 50 => ageBands[4],
    _ => ageBands[5],
  };
  bool get isValid =>
      age >= 18 &&
      genders.contains(gender) &&
      seekingOptions.contains(seeking) &&
      bio.trim().length <= 240 &&
      cityId.isNotEmpty &&
      photoCount >= 1 &&
      photoCount <= 3;
}

class JobsProfile {
  const JobsProfile({
    required this.role,
    required this.tradeId,
    required this.cityId,
    required this.salaryBand,
    this.photoCount = 0,
    this.howMany,
  });
  final String role;
  final String tradeId;
  final String cityId;
  final String salaryBand;
  final int photoCount;

  /// Demand only (“I need”) — how many people. Null on supply.
  final String? howMany;

  String get needLine => tradeId;
  bool get isDemand => role == 'offer';
  bool get isValid =>
      roles.contains(role) &&
      trades.contains(tradeId) &&
      cityId.isNotEmpty &&
      salaryBands.contains(salaryBand) &&
      photoCount <= 3 &&
      (isDemand || photoCount >= 1) &&
      (!isDemand || howManyOptions.contains(howMany));

  /// Post + filter role ids (seek = I have, offer = I need).
  static const roles = <String>['seek', 'offer'];
  static String roleLabel(String role) => switch (role) {
    'seek' => 'I have',
    'offer' => 'I need',
    _ => role,
  };

  /// Necessity chips for demand listings.
  static const howManyOptions = <String>['1', '2', '3', '4', '5', 'Team'];

  static const trades = <String>[
    'Cook',
    'Driver',
    'Domestic help',
    'Delivery',
    'Security',
    'Construction',
    'Electrician',
    'Plumber',
    'Warehouse',
    'Shop/Retail',
    'Office/Desk',
    'Cleaning',
  ];
  static const salaryBands = <String>[
    'Prefer not to say',
    'Under ₹10k/mo',
    '₹10–15k/mo',
    '₹15–25k/mo',
    '₹25–40k/mo',
    '₹40–60k/mo',
    '₹60k+/mo',
  ];
}

/// Kuwait / Mid-East jobs (oilfield, camp, drivers). Available = seek, Wanted = offer.
class KuwaitJobsProfile {
  const KuwaitJobsProfile({
    required this.role,
    required this.tradeIds,
    required this.countryId,
    required this.salaryBand,
    required this.nationality,
    required this.experienceBand,
    this.photoCount = 0,
    this.howMany,
  });

  final String role;

  /// 1–5 positions (primary first). Prefer [tradeIds]; [tradeId] is convenience.
  final List<String> tradeIds;
  final String countryId;
  final String salaryBand;
  final String nationality;
  final String experienceBand;
  final int photoCount;
  final String? howMany;

  String get tradeId => tradeIds.isEmpty ? trades.first : tradeIds.first;

  bool get isDemand => role == 'offer';
  bool get isValid =>
      roles.contains(role) &&
      tradeIds.isNotEmpty &&
      tradeIds.length <= maxTrades &&
      tradeIds.every(trades.contains) &&
      countryIds.contains(countryId) &&
      salaryBandsFor(countryId).contains(salaryBand) &&
      nationalities.contains(nationality) &&
      experienceBands.contains(experienceBand) &&
      photoCount <= 3 &&
      (isDemand || photoCount >= 1) &&
      (!isDemand || howManyOptions.contains(howMany));

  static const roles = <String>['seek', 'offer'];
  static String roleLabel(String role) => switch (role) {
    'seek' => 'Available',
    'offer' => 'Wanted',
    _ => role,
  };

  static const howManyOptions = <String>['1', '2', '3', '4', '5', 'Team'];

  static const trades = <String>[
    'AC Mechanic',
    'Accountant',
    'Assistant Cook',
    'Asst Driller',
    'Camp Boss',
    'Car Mechanic',
    'Cashier',
    'Cementer',
    'Cementing Engineer',
    'Construction Worker',
    'Cook',
    'DD',
    'DD Planner',
    'DD/Mwd Coordinator',
    'Derrikman',
    'Driller',
    'Drilling Er',
    'Driver Ambulance',
    'Driver Crane',
    'Driver Tanker',
    'Driver-Pickup',
    'Electrician',
    'Field Helper',
    'Fishing Engineer',
    'Floorman',
    'Heavy Driver',
    'Helper',
    'Home Maid',
    'Hotel Crew',
    'HSE Supervisor',
    'IT / Computer Engineer',
    'Laundry boy',
    'Logging Engineer',
    'Manager',
    'Material Dispatcher',
    'Mechanic',
    'Medic',
    'MWD',
    'Night Tool Pusher',
    'Nurse',
    'Office Jobs',
    'Office Secretary',
    'Office Service Coordinator',
    'Others',
    'Plumber',
    'Receptionist',
    'Rig Manager',
    'Rig Superintendent',
    'Room boy',
    'Roustabout',
    'Safety Er',
    'Sales Manager',
    'Salesman',
    'Storekeeper',
    'Tool Pusher',
  ];

  /// Roles that must always appear on the Position picker (A–Z with the rest).
  static const requiredTrades = <String>[
    'Cementer',
    'Cementing Engineer',
    'DD',
    'DD Planner',
    'DD/Mwd Coordinator',
    'Drilling Er',
    'Field Helper',
    'Fishing Engineer',
    'IT / Computer Engineer',
    'Logging Engineer',
    'Material Dispatcher',
    'MWD',
    'Office Jobs',
    'Office Secretary',
    'Office Service Coordinator',
    'Others',
    'Safety Er',
    'Storekeeper',
  ];

  static const maxTrades = 5;

  /// Browse / Likes title: first job, or `Cook +2` when multiple.
  static String titleLine(List<String> selected) {
    final clean = normalizeTrades(selected);
    if (clean.isEmpty) return '';
    if (clean.length == 1) return clean.first;
    return '${clean.first} +${clean.length - 1}';
  }

  /// Keep 1–[maxTrades] valid trades; migrate legacy single [tradeId].
  static List<String> normalizeTrades(
    Iterable<Object?>? raw, {
    String? legacyTradeId,
  }) {
    final out = <String>[];
    void add(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty || !trades.contains(v) || out.contains(v)) return;
      if (out.length >= maxTrades) return;
      out.add(v);
    }

    if (raw != null) {
      for (final item in raw) {
        add('$item');
      }
    }
    add(legacyTradeId);
    if (out.isEmpty) out.add(trades.first);
    return List<String>.unmodifiable(out);
  }

  static const countryIds = <String>[
    'kuwait',
    'saudi',
    'qatar',
    'oman',
    'egypt',
    'uae',
    'others',
  ];

  static const countryLabels = <String, String>{
    'kuwait': 'Kuwait',
    'saudi': 'Saudi',
    'qatar': 'Qatar',
    'oman': 'Oman',
    'egypt': 'Egypt',
    'uae': 'UAE',
    'others': 'Others',
  };

  static String currencyFor(String countryId) => switch (countryId) {
    'kuwait' => 'KWD',
    'saudi' => 'SAR',
    'qatar' => 'QAR',
    'oman' => 'OMR',
    'egypt' => 'EGP',
    'uae' => 'AED',
    'others' => 'USD',
    _ => 'KWD',
  };

  static const salaryBandKeys = <String>[
    'prefer_not',
    'under_100',
    '100_200',
    '200_400',
    '400_600',
    '600_1000',
    '1000_plus',
  ];

  static String salaryLabel(String key, String currency) => switch (key) {
    'prefer_not' => 'Prefer not to say',
    'under_100' => 'Under $currency 100/mo',
    '100_200' => '$currency 100–200/mo',
    '200_400' => '$currency 200–400/mo',
    '400_600' => '$currency 400–600/mo',
    '600_1000' => '$currency 600–1000/mo',
    '1000_plus' => '$currency 1000+/mo',
    _ => 'Prefer not to say',
  };

  static List<String> salaryBandsFor(String countryId) {
    final currency = currencyFor(countryId);
    return [
      for (final key in salaryBandKeys) salaryLabel(key, currency),
    ];
  }

  static const nationalities = <String>[
    'Indian',
    'Pakistan',
    'Chinese',
    'Egyptian',
    'Indonesia',
    'Bangladesh',
    'Any',
    'Others',
  ];

  static const experienceBands = <String>['0–1', '1–3', '3–5', '5+'];
}

class RoomsOffer {
  const RoomsOffer({
    required this.type,
    required this.furnishing,
    required this.monthlyRent,
    required this.depositMonths,
    required this.cityId,
    required this.photoCount,
    this.amenities = const <String>[],
    this.hasAddressProof = false,
  });
  final String type;
  final String furnishing;
  final int monthlyRent;
  final int depositMonths;
  final String cityId;
  final int photoCount;
  final List<String> amenities;
  final bool hasAddressProof;

  static const types = <String>[
    'Room',
    'Studio',
    '1 BHK',
    '2 BHK',
    '3 BHK',
    'PG',
  ];
  static const furnishingOptions = <String>[
    'Unfurnished',
    'Semi',
    'Fully furnished',
  ];
  static const rentPresets = <int>[
    8000,
    12000,
    15000,
    20000,
    25000,
    35000,
    50000,
  ];
  static const depositOptions = <int>[0, 1, 2, 3];
  static const amenityOptions = <String>[
    'Wi-Fi',
    'AC',
    'Parking',
    'Kitchen',
    'Balcony',
    'Power backup',
  ];

  String get title => type;
  String get subtitle => '₹$monthlyRent/month';

  bool get isValid =>
      types.contains(type) &&
      furnishingOptions.contains(furnishing) &&
      cityId.isNotEmpty &&
      amenities.every(amenityOptions.contains) &&
      photoCount >= 2 &&
      photoCount <= 8 &&
      monthlyRent > 0 &&
      depositMonths >= 0 &&
      depositMonths <= 3;
}

class BikesOffer {
  const BikesOffer({
    required this.type,
    required this.transmission,
    required this.make,
    required this.hourlyRent,
    required this.photoCount,
    this.cityId = 'mumbai',
    this.model,
    this.availableWeekdays = weekdays,
    this.fromTime = '09:00',
    this.toTime = '20:00',
    this.hasRc = false,
    this.hasInsurance = false,
  });
  final String type;
  final String transmission;
  final String make;
  final int hourlyRent;
  final int photoCount;
  final String cityId;
  final String? model;
  final List<String> availableWeekdays;
  final String fromTime;
  final String toTime;
  final bool hasRc;
  final bool hasInsurance;

  static const types = <String>['Scooter', 'Bike'];
  static const transmissions = <String>['automatic', 'geared'];
  static const makes = <String>[
    'Honda',
    'Hero',
    'TVS',
    'Bajaj',
    'Yamaha',
    'Royal Enfield',
    'Suzuki',
    'Other',
  ];
  static const hourlyRentPresets = <int>[50, 80, 100, 150, 200];
  static const weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String get title =>
      '$make ${model?.trim().isNotEmpty == true ? model!.trim() : type}';
  String get subtitle => '₹$hourlyRent/hour';

  bool get isValid =>
      types.contains(type) &&
      transmissions.contains(transmission) &&
      makes.contains(make) &&
      cityId.isNotEmpty &&
      availableWeekdays.isNotEmpty &&
      availableWeekdays.every(weekdays.contains) &&
      RegExp(r'^\d\d:\d\d$').hasMatch(fromTime) &&
      RegExp(r'^\d\d:\d\d$').hasMatch(toTime) &&
      hourlyRent > 0 &&
      photoCount == 4;

  Map<String, Object> get publicAttributes => {
    'type': type,
    'transmission': transmission,
    'make': make,
    'hourlyRent': hourlyRent,
    'model': model ?? '',
    'availableWeekdays': availableWeekdays,
    'fromTime': fromTime,
    'toTime': toTime,
    'hasRc': hasRc,
    'hasInsurance': hasInsurance,
  };
}

class HomeHelpOffer {
  const HomeHelpOffer({
    required this.role,
    required this.service,
    required this.shift,
    required this.salaryBand,
    required this.languages,
    required this.photoCount,
    this.cityId = 'mumbai',
    this.howMany,
  });
  final String role;
  final String service;
  final String shift;
  final String salaryBand;
  final List<String> languages;
  final int photoCount;
  final String cityId;

  /// Demand only (“I need”) — how many people.
  final String? howMany;

  static const roles = <String>['have', 'need'];
  static const howManyOptions = <String>['1', '2', '3', '4', '5', 'Team'];
  static const services = <String>[
    'Cook',
    'Maid',
    'Ayah/Nanny',
    'Elder care',
    'Driver',
    'Deep cleaner',
  ];
  static const shifts = <String>['Part-time', 'Full-time', 'Live-in'];
  static const salaryBands = <String>[
    '₹5–8k',
    '₹8–12k',
    '₹12–18k',
    '₹18–25k',
    '₹25k+',
  ];
  static const languageOptions = <String>[
    'Hindi',
    'English',
    'Marathi',
    'Tamil',
    'Telugu',
    'Kannada',
    'Bengali',
    'Gujarati',
    'Punjabi',
    'Malayalam',
  ];

  String get title => service;
  String get subtitle => '$shift · $salaryBand';
  bool get isDemand => role == 'need';

  bool get isValid =>
      roles.contains(role) &&
      services.contains(service) &&
      shifts.contains(shift) &&
      salaryBands.contains(salaryBand) &&
      cityId.isNotEmpty &&
      languages.isNotEmpty &&
      languages.every(languageOptions.contains) &&
      photoCount <= 4 &&
      (role == 'need' || photoCount >= 1) &&
      (!isDemand || howManyOptions.contains(howMany));
}
