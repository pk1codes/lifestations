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
    < 25 => '18-24',
    < 30 => '25-29',
    < 35 => '30-34',
    < 40 => '35-39',
    < 50 => '40-49',
    _ => '50+',
  };
  bool get isValid =>
      age >= 18 &&
      genders.contains(gender) &&
      seekingOptions.contains(seeking) &&
      bio.trim().length >= 10 &&
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
  });
  final String role;
  final String tradeId;
  final String cityId;
  final String salaryBand;

  String get needLine =>
      role == 'seek' ? 'Looking for $tradeId work' : 'Need $tradeId help';
  bool get isValid =>
      const {'seek', 'offer'}.contains(role) &&
      trades.contains(tradeId) &&
      cityId.isNotEmpty &&
      salaryBands.contains(salaryBand);

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

  String get title => '$type for rent';
  String get subtitle => '₹$monthlyRent/month • $furnishing';

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
  String get subtitle => '₹$hourlyRent/hour • $fromTime–$toTime';

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
  });
  final String role;
  final String service;
  final String shift;
  final String salaryBand;
  final List<String> languages;
  final int photoCount;
  final String cityId;

  static const roles = <String>['have', 'need'];
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

  String get title => role == 'have' ? '$service available' : '$service needed';
  String get subtitle => '${role == 'have' ? 'Available' : 'Hiring'} • $shift';

  bool get isValid =>
      roles.contains(role) &&
      services.contains(service) &&
      shifts.contains(shift) &&
      salaryBands.contains(salaryBand) &&
      cityId.isNotEmpty &&
      languages.isNotEmpty &&
      languages.every(languageOptions.contains) &&
      photoCount <= 4 &&
      (role == 'need' || photoCount >= 1);
}
