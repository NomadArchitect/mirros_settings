# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

Setting.create(
  [
    {
      category: 'display',
      key: 'orientation',
      value: '1'
    },
    {
      category: 'display',
      key: 'offInterval',
      value: 'off'
    },
    {
      category: 'display',
      key: 'offIntervalStart',
      value: ''
    },
    {
      category: 'display',
      key: 'offIntervalEnd',
      value: ''
    },
    {
      category: 'network',
      key: 'connectionType',
      value: 'wlan'
    },
    {
      category: 'network',
      key: 'ssid',
      value: ''
    },
    {
      category: 'network',
      key: 'ssidInvisible',
      value: 'no' # Requires frontend to specify checkbox values.
    },
    {
      category: 'network',
      key: 'password',
      value: ''
    },
    {
      category: 'system',
      key: 'language',
      value: '' # Settings SPA defaults to browser language until user chooses a language.

    },
    {
      category: 'personal',
      key: 'email',
      value: ''
    },
    {
      category: 'personal',
      key: 'name',
      value: ''
    },
    {
      category: 'personal',
      key: 'privacyConsent',
      value: 'no' # Requires frontend to specify checkbox values.
    }
  ]
)


Group.create(
  [
    {
      name: 'calendar'
    },
    {
      name: 'reminder_list'
    },
    {
      name: 'weather'
    },
    {
      name: 'news'
    },
    {
      name: 'public_transport'
    },
    {
      name: 'fuel'
    },
    {
      name: 'traffic'
    },
    {
      name: 'music_player'
    }
  ]
)

# Only seed test data in development
if Rails.env.development?

  Widget.create(
    [
      {
        name: 'calendar_week',
        title: {'en_GB' => 'Week Overview', 'de_DE' => 'Wochenüberblick'},
        description: {'en_GB' => 'Displays up to five calendars in a week view.', 'de_DE' => 'Zeigt bis zu fünf Kalender in einer Wochenübersicht an.'},
        creator: 'Mattes Angelus',
        version: '1.0.0',
        website: 'https://glancr.de/module/produktivitaet/kalender/',
        download: 'https://api.glancr.de/extensions/widgets/calendar_week-1.0.0.zip',
        languages: ['en_GB'],
        group_id: Group.find_by(name: 'calendar')
      },
      {
        name: 'calendar_today',
        title: {'en_GB' => 'Today', 'de_DE' => 'Heute'},
        description: {'en_GB' => 'Displays today\'s calendar events.', 'de_DE' => 'Deine Termine für den heutigen Tag.'},
        creator: 'Mattes Angelus',
        version: '1.0.0',
        website: 'https://glancr.de/module/produktivitaet/kalender/',
        download: 'https://api.glancr.de/extensions/widgets/calendar_today-1.0.0.zip',
        languages: ['en_GB'],
        group_id: Group.find_by(name: 'calendar')
      },
      {
        name: 'todoist',
        title: {'en_GB' => 'Todoist', 'de_DE' => 'Todoist'},
        description: {'en_GB' => 'Shows your tasks from Todoist on your glancr.', 'de_DE' => 'Zeigt deine Aufgaben aus Todoist auf deinem glancr an.'},
        creator: 'Marco Roth',
        version: '1.0.0',
        website: 'https://glancr.de/module/produktivitaet/todos/',
        download: 'https://api.glancr.de/extensions/widgets/todos-1.0.0.zip',
        languages: ['en_GB'],
        group_id: Group.find_by(name: 'reminder_list')
      }
    ]
  )

  Source.create(
    [
      {
        name: 'google',
        title: {'en_GB' => 'Google', 'de_DE' => 'Google'},
        description: {'en_GB' => 'Access data from your Google account. Supports Calendar and Tasks.',
                      'de_DE' => 'Greife auf Daten aus deinem Google-Konto zu. Unterstützt Kalender und Aufgaben.'},
        creator: 'Mattes Angelus',
        version: '1.0.0',
        website: '',
        download: 'https://api.glancr.de/extensions/sources/google-1.0.0.zip',
        groups: [Group.find_by(name: 'calendar'), Group.find_by(name: 'reminder_list')]
      },
      {
        name: 'icloud',
        title: {'en_GB' => 'iCloud', 'de_DE' => 'iCloud'},
        description: {'en_GB' => 'Access data from your iCloud account. Supports Calendar and Tasks.',
                      'de_DE' => 'Greife auf Daten aus deinem iCloud-Konto zu. Unterstützt Kalender und Aufgaben.'},
        creator: 'Mattes Angelus',
        version: '1.0.0',
        website: '',
        download: 'https://api.glancr.de/extensions/sources/icloud-1.0.0.zip',
        groups: [Group.find_by(name: 'calendar'), Group.find_by(name: 'reminder_list')]
      },
      {
        name: 'ical',
        title: {'en_GB' => 'iCalendar', 'de_DE' => 'iCalendar'},
        description: {'en_GB' => 'Access data from online calendars in iCal format. Supports both public and password-protected iCal links.',
                      'de_DE' => 'Greife auf Daten aus Online-Kalendern im iCal-Format zu. Unterstützt sowohl öffentliche als auch passwortgeschützte iCal-Links.'},
        creator: 'Mattes Angelus',
        version: '1.0.0',
        website: '',
        download: 'https://api.glancr.de/extensions/sources/ical-1.0.0.zip',
        groups: [Group.find_by(name: 'calendar')]
      }
    ]
  )

  Service.create(
    [
      {
        status: 'running',
        parameters: {
          key: 'value'
        },
        # widget: Widget.first
        widget_id: Widget.first
      },
      {
        status: 'stopped',
        parameters: {
          key: 'value'
        },
        # widget: Widget.last
        widget_id: Widget.first
      }
    ]
  )

  WidgetInstance.create(
    [
      {
        widget: Widget.find_by(name: 'calendar_today'),
        position: {
          x: 1,
          y: 1,
          width: 2,
          height: 2
        }
      },
      {
        widget: Widget.find_by(name: 'calendar_week'),
        position: {
          x: 10,
          y: 6,
          width: 4,
          height: 2
        }
      }
    ]
  )

  SourceInstance.create(
    [
      {
        source: Source.find_by(name: 'ical'),
        title: 'calendar',
        configuration: {'url': 'https://calendar.google.com/calendar/ical/de.german%23holiday%40group.v.calendar.google.com/public/basic.ics'}
      }
    ]
  )

  InstanceAssociation.create(
    [
      {
        configuration: {'chosen': ['calendar']},
        group: Group.find_by(name: 'calendar'),
        widget_instance: WidgetInstance.find_by(widget_id: 'calendar_today'),
        source_instance: SourceInstance.find_by(source_id: 'ical')
      }
    ]
  )

  # Use the parent class since ical extension might not be installed
  cal_seed = GroupSchemas::Calendar.create(
    [
      {
        uid: "#{SourceInstance.first.id}_calendar",
        type: 'Ical::Calendar',
        name: 'calendar'
      }
    ]
  )

  cal_seed.first.events << GroupSchemas::CalendarEvent.create(
    [
      {
        uid: SecureRandom.uuid,
        dtstart: DateTime.now,
        dtend: DateTime.now + 2,
        all_day: false,
        summary: 'A test event in calendar',
        description: 'A description of test event'
      },
      {
        uid: SecureRandom.uuid,
        dtstart: Date.today + 2,
        dtend: Date.today + 4,
        all_day: true,
        summary: 'A second test event in calendar',
        description: 'A description of second test event'
      }
    ]
  )

  reminders_seed = GroupSchemas::ReminderList.create(
    [
      {
        uid: "#{SourceInstance.first.id}_reminders",
        type: 'Ical::ReminderList',
        name: 'reminders'
      }
    ]
  )

  RecordLink.create(
    [
      {
        source_instance: SourceInstance.find_by(source_id: 'ical'),
        group: Group.find('calendar'),
        recordable_type: 'GroupSchemas::Calendar',
        recordable: cal_seed.first
      },
      {
        source_instance: SourceInstance.find_by(source_id: 'ical'),
        group: Group.find('reminder_list'),
        recordable_type: 'GroupSchemas::ReminderList',
        recordable: reminders_seed.first
      }
    ]
  )
else
  # No seeding
end
