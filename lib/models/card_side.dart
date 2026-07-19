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
            : 'Looking for $seeking',
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

/// One short fact line for the Browse card.
String cardFactLine(DiscoveryCardModel card) {
  final attrs = card.attributes;
  switch (card.domain) {
    case AppDomainId.marriage:
      final bits = <String>[
        if (card.ageBand?.isNotEmpty ?? false) card.ageBand!,
        if ((attrs['gender'] as String?)?.isNotEmpty ?? false)
          attrs['gender'] as String,
      ];
      if (bits.isNotEmpty) return bits.join(' • ');
      return card.subtitle;
    case AppDomainId.jobs:
      final trade = card.categoryTags.isNotEmpty
          ? card.categoryTags.first
          : (attrs['tradeId'] as String?);
      final pay = (attrs['salaryBand'] as String?) ?? '';
      final bits = <String>[
        if (trade != null && trade.isNotEmpty) trade,
        if (pay.isNotEmpty) pay,
      ];
      if (bits.isNotEmpty) return bits.join(' • ');
      return card.subtitle;
    case AppDomainId.rooms:
      final type = (attrs['type'] as String?) ??
          (card.categoryTags.isNotEmpty ? card.categoryTags.first : null);
      final rent = attrs['monthlyRent'];
      final bits = <String>[
        if (type != null && type.isNotEmpty) type,
        if (rent != null) '₹$rent/month',
      ];
      if (bits.isNotEmpty) return bits.join(' • ');
      return card.subtitle;
    case AppDomainId.bikes:
      return card.subtitle;
    case AppDomainId.homeHelp:
      final service = (attrs['service'] as String?) ??
          (card.categoryTags.isNotEmpty ? card.categoryTags.first : null);
      final shift = attrs['shift'] as String?;
      final pay = attrs['salaryBand'] as String?;
      final bits = <String>[
        if (service != null && service.isNotEmpty) service,
        if (shift != null && shift.isNotEmpty) shift,
        if (pay != null && pay.isNotEmpty) pay,
      ];
      if (bits.isNotEmpty) return bits.join(' • ');
      return card.subtitle;
  }
}
