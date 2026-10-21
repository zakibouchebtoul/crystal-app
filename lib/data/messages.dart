/// Conversations for the Messages tab. Sample data until the messaging
/// backend is connected.
library;

import 'package:flutter/painting.dart';

enum AvatarKind { crystal, initials, group }

class Conversation {
  const Conversation({
    required this.name,
    required this.subtitle,
    required this.time,
    required this.avatar,
    this.initials,
    this.avatarColor,
    this.initialsColor,
    this.online,
    this.history = const [],
    this.quickReplies = const [],
  });

  final String name;
  final String subtitle;

  /// Last activity label, e.g. "2m" or "Yesterday".
  final String time;

  final AvatarKind avatar;
  final String? initials;
  final Color? avatarColor;
  final Color? initialsColor;

  /// Green dot when true, gray when false, none when null.
  final bool? online;

  final List<ChatItem> history;
  final List<String> quickReplies;
}

sealed class ChatItem {
  const ChatItem();
}

class ChatText extends ChatItem {
  const ChatText(this.text, {this.mine = false, this.seen = false});

  final String text;

  /// Sent by the user.
  final bool mine;

  /// Read by the other side (shown under the user's last message).
  final bool seen;
}

class ChatBooking extends ChatItem {
  const ChatBooking({
    required this.title,
    required this.when,
    required this.image,
    required this.provider,
    required this.price,
    required this.rating,
    required this.reviews,
  });

  final String title;
  final String when;
  final String image;
  final String provider;
  final int price;
  final double rating;
  final String reviews;
}

const _services = 'assets/images/home/services';

const sampleConversations = [
  Conversation(
    name: 'Crystal Support',
    subtitle: 'Support team',
    time: '2m',
    avatar: AvatarKind.crystal,
    online: true,
    history: [
      ChatText(
        'Hi Bo! Just confirming your car wash is rebooked for Thursday '
        '10 AM as discussed with the concierge.',
      ),
      ChatText('Perfect, thank you!', mine: true, seen: true),
      ChatText(
        "You're welcome. We'll also send someone for the carpet today "
        'between 2–4 PM.',
      ),
      ChatBooking(
        title: 'Carpet cleaning',
        when: 'Today · 2:00–4:00 PM',
        image: '$_services/carpet.jpg',
        provider: 'Qatar wash',
        price: 59,
        rating: 4.9,
        reviews: '2.1k',
      ),
    ],
    quickReplies: [
      'Great, thanks!',
      'Can we move to 3 PM?',
      'What do I need to prepare?',
    ],
  ),
  Conversation(
    name: 'AK Ahmed K.',
    subtitle: 'Your cleaner · Deep cleaning',
    time: '18m',
    avatar: AvatarKind.initials,
    initials: 'AK',
    avatarColor: Color(0xFFFFE9C7),
    initialsColor: Color(0xFFF5A100),
    online: true,
    history: [
      ChatText("Hi! I'm on my way, I'll be there in about 15 minutes."),
      ChatText('Great, the gate code is 4821.', mine: true, seen: true),
    ],
    quickReplies: ['Thanks!', 'Please call when you arrive'],
  ),
  Conversation(
    name: 'Deep Clean Team · #4821',
    subtitle: 'Group · 3 members',
    time: '32m',
    avatar: AvatarKind.group,
    avatarColor: Color(0xFF6A7B89),
    online: true,
    history: [
      ChatText('Team assigned for your deep clean tomorrow at 9 AM.'),
      ChatText('We will bring all the supplies.'),
    ],
    quickReplies: ['Sounds good', 'Can you bring a ladder?'],
  ),
  Conversation(
    name: 'Crystal Bookings',
    subtitle: 'Automated updates',
    time: '1h',
    avatar: AvatarKind.crystal,
    history: [
      ChatText('Your booking #4821 is confirmed for tomorrow, 9:00 AM.'),
    ],
  ),
  Conversation(
    name: 'Sara M.',
    subtitle: 'Your cleaner · House clean',
    time: 'Yesterday',
    avatar: AvatarKind.initials,
    initials: 'SM',
    avatarColor: Color(0xFFF7CDFB),
    initialsColor: Color(0xFFFFFFFF),
    online: false,
    history: [
      ChatText('All done! I left the keys with the reception.'),
      ChatText(
        'Thank you Sara, the house looks amazing!',
        mine: true,
        seen: true,
      ),
    ],
    quickReplies: ['Thanks again!'],
  ),
];
