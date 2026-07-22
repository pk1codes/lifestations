import 'package:flutter/material.dart';

import 'app_domain.dart';
import 'discovery_card.dart';

/// Visual marketplace side for Browse cards.
enum MarketplaceSide { supply, demand, match }

@immutable
class CardSideMark {
  const CardSideMark({
    required this.side,
    required this.label,
    required this.icon,
    required this.color,
  });

  final MarketplaceSide side;
  final String label;
  final IconData icon;
  final Color color;

  /// Marketplace sides — kept off the domain palette so they never collide.
  static const supplyColor = Color(0xFF059669); // green = I have
  static const demandColor = Color(0xFFEA580C); // orange = I need
  static const matchColor = Color(0xFFBE185D); // marriage rose
}

CardSideMark? cardSideMark(DiscoveryCardModel card) {
  switch (card.domain) {
    case AppDomainId.marriage:
      final seeking =
          (card.attributes['seeking'] as String?) ??
          (card.role?.isNotEmpty == true ? card.role : null);
      return CardSideMark(
        side: MarketplaceSide.match,
        label: seeking == null || seeking.isEmpty
            ? 'Looking to marry'
            : 'Looking for ${_prettyLabel(seeking)}',
        icon: Icons.favorite_outline,
        color: CardSideMark.matchColor,
      );
    case AppDomainId.jobs:
      if (card.role == 'offer') {
        return const CardSideMark(
          side: MarketplaceSide.demand,
          label: 'I need',
          icon: Icons.person_search_outlined,
          color: CardSideMark.demandColor,
        );
      }
      return const CardSideMark(
        side: MarketplaceSide.supply,
        label: 'I have',
        icon: Icons.handyman_outlined,
        color: CardSideMark.supplyColor,
      );
    case AppDomainId.homeHelp:
      if (card.role == 'need') {
        return const CardSideMark(
          side: MarketplaceSide.demand,
          label: 'I need',
          icon: Icons.person_search_outlined,
          color: CardSideMark.demandColor,
        );
      }
      return const CardSideMark(
        side: MarketplaceSide.supply,
        label: 'I have',
        icon: Icons.volunteer_activism_outlined,
        color: CardSideMark.supplyColor,
      );
    case AppDomainId.rooms:
      if (card.role == 'need' || card.role == 'want') {
        return const CardSideMark(
          side: MarketplaceSide.demand,
          label: 'I need',
          icon: Icons.search,
          color: CardSideMark.demandColor,
        );
      }
      return const CardSideMark(
        side: MarketplaceSide.supply,
        label: 'I have',
        icon: Icons.home_outlined,
        color: CardSideMark.supplyColor,
      );
    case AppDomainId.bikes:
      if (card.role == 'need' || card.role == 'want') {
        return const CardSideMark(
          side: MarketplaceSide.demand,
          label: 'I need',
          icon: Icons.search,
          color: CardSideMark.demandColor,
        );
      }
      return const CardSideMark(
        side: MarketplaceSide.supply,
        label: 'I have',
        icon: Icons.pedal_bike,
        color: CardSideMark.supplyColor,
      );
  }
}

/// Necessity title on Browse / Likes / My posts — what the card is.
/// Side strip carries have/need / looking-for; this line does not repeat that.
///
/// When [allowFallback] is false (public share), never copy free-text [card.title].
String cardTitleLine(DiscoveryCardModel card, {bool allowFallback = true}) {
  final attrs = card.attributes;
  switch (card.domain) {
    case AppDomainId.marriage:
      final age = card.ageBand?.trim() ?? '';
      final gender = (attrs['gender'] as String?)?.trim() ?? '';
      if (age.isNotEmpty && gender.isNotEmpty) {
        return '$age · ${_prettyLabel(gender)}';
      }
      if (age.isNotEmpty) return age;
      return allowFallback ? _fallbackTitle(card) : '';
    case AppDomainId.jobs:
      final trade = _firstNonEmpty([
        attrs['tradeId'] as String?,
        if (card.categoryTags.isNotEmpty) card.categoryTags.first,
      ]);
      if (trade != null) return _prettyLabel(trade);
      return allowFallback ? _fallbackTitle(card) : '';
    case AppDomainId.rooms:
      final type = _firstNonEmpty([
        attrs['type'] as String?,
        if (card.categoryTags.isNotEmpty) card.categoryTags.first,
      ]);
      if (type != null) return type;
      return allowFallback ? _fallbackTitle(card) : '';
    case AppDomainId.bikes:
      final make = attrs['make'] as String?;
      final model = attrs['model'] as String?;
      final type =
          attrs['type'] as String? ??
          (card.categoryTags.length > 1 ? card.categoryTags[1] : null) ??
          (card.categoryTags.isNotEmpty ? card.categoryTags.first : null);
      if (make != null && make.trim().isNotEmpty) {
        final rest = (model != null && model.trim().isNotEmpty)
            ? model.trim()
            : (type ?? '');
        return rest.isEmpty ? make.trim() : '${make.trim()} $rest';
      }
      if (type != null && type.trim().isNotEmpty) {
        return _prettyLabel(type);
      }
      return allowFallback ? _fallbackTitle(card) : '';
    case AppDomainId.homeHelp:
      final service = _firstNonEmpty([
        attrs['service'] as String?,
        if (card.categoryTags.isNotEmpty) card.categoryTags.first,
      ]);
      if (service != null) return _prettyLabel(service);
      return allowFallback ? _fallbackTitle(card) : '';
  }
}

/// Second line: money or one extra fact — never repeats the title.
String cardFactLine(DiscoveryCardModel card) {
  final attrs = card.attributes;
  switch (card.domain) {
    case AppDomainId.marriage:
      // Age + gender are the title; seeking is the side strip.
      return '';
    case AppDomainId.jobs:
      final howMany = (attrs['howMany'] as String?)?.trim() ?? '';
      final pay = (attrs['salaryBand'] as String?)?.trim() ?? '';
      final payLine = pay.isNotEmpty ? pay : _moneyFromSubtitle(card.subtitle);
      if (card.role == 'offer' && howMany.isNotEmpty) {
        return payLine.isEmpty ? 'Need $howMany' : 'Need $howMany · $payLine';
      }
      return payLine;
    case AppDomainId.rooms:
      final rent = attrs['monthlyRent'];
      if (rent != null) return '₹$rent/month';
      return _moneyFromSubtitle(card.subtitle);
    case AppDomainId.bikes:
      final hourly = attrs['hourlyRent'];
      if (hourly != null) return '₹$hourly/hour';
      return _moneyFromSubtitle(card.subtitle);
    case AppDomainId.homeHelp:
      final howMany = (attrs['howMany'] as String?)?.trim() ?? '';
      final shift = (attrs['shift'] as String?)?.trim() ?? '';
      final pay = (attrs['salaryBand'] as String?)?.trim() ?? '';
      final bits = <String>[
        if (card.role == 'need' && howMany.isNotEmpty) 'Need $howMany',
        if (shift.isNotEmpty) shift,
        if (pay.isNotEmpty) pay,
      ];
      if (bits.isNotEmpty) return bits.join(' · ');
      return '';
  }
}

String _fallbackTitle(DiscoveryCardModel card) {
  var title = card.title.trim();
  if (title.isEmpty) return 'Post';
  // Strip legacy domain prefixes / long job sentences when attrs missing.
  title = title.replaceFirst(
    RegExp(r'^Marriage\s*[·•\-–]\s*', caseSensitive: false),
    '',
  );
  title = title.replaceFirst(
    RegExp(r'^Looking for\s+', caseSensitive: false),
    '',
  );
  title = title.replaceFirst(RegExp(r'\s+work$', caseSensitive: false), '');
  title = title.replaceFirst(RegExp(r'^Need\s+', caseSensitive: false), '');
  title = title.replaceFirst(RegExp(r'\s+help$', caseSensitive: false), '');
  title = title.replaceFirst(RegExp(r'\s+for rent$', caseSensitive: false), '');
  title = title.replaceFirst(
    RegExp(r'\s+available$', caseSensitive: false),
    '',
  );
  title = title.replaceFirst(RegExp(r'\s+needed$', caseSensitive: false), '');
  return title.trim().isEmpty ? card.title.trim() : title.trim();
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _prettyLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (t.length == 1) return t.toUpperCase();
  return '${t[0].toUpperCase()}${t.substring(1)}';
}

/// Pull a leading ₹… segment from legacy subtitles.
String _moneyFromSubtitle(String subtitle) {
  final match = RegExp(r'₹[^•·]+').firstMatch(subtitle);
  if (match == null) return '';
  return match.group(0)!.trim();
}
