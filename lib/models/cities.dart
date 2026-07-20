/// Shared city list for all domain forms — Indian state/UT capitals.
/// Short labels, A–Z by display name. Used by [CityDropdown] everywhere.
const cityLabels = <String, String>{
  'agartala': 'Agartala',
  'aizawl': 'Aizawl',
  'amaravati': 'Amaravati',
  'bengaluru': 'Bengaluru',
  'bhopal': 'Bhopal',
  'bhubaneswar': 'Bhubaneswar',
  'chandigarh': 'Chandigarh',
  'chennai': 'Chennai',
  'dehradun': 'Dehradun',
  'delhi': 'Delhi NCR',
  'dispur': 'Dispur',
  'gandhinagar': 'Gandhinagar',
  'gangtok': 'Gangtok',
  'hyderabad': 'Hyderabad',
  'imphal': 'Imphal',
  'itanagar': 'Itanagar',
  'jaipur': 'Jaipur',
  'jammu': 'Jammu',
  'kavaratti': 'Kavaratti',
  'kohima': 'Kohima',
  'kolkata': 'Kolkata',
  'leh': 'Leh',
  'lucknow': 'Lucknow',
  'mumbai': 'Mumbai',
  'panaji': 'Panaji',
  'patna': 'Patna',
  'port_blair': 'Port Blair',
  'puducherry': 'Puducherry',
  'raipur': 'Raipur',
  'ranchi': 'Ranchi',
  'shillong': 'Shillong',
  'shimla': 'Shimla',
  'srinagar': 'Srinagar',
  'thiruvananthapuram': 'Thiruvananthapuram',
};

/// City ids sorted A–Z by label for dropdowns.
List<MapEntry<String, String>> get citiesAz =>
    (cityLabels.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase())));
