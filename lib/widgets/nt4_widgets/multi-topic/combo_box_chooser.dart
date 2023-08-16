import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComboBoxChooser extends StatelessWidget with NT4Widget {
  @override
  String type = 'ComboBox Chooser';

  late String optionsTopicName;
  late String selectedTopicName;
  late String activeTopicName;
  late String defaultTopicName;

  String? selectedChoice;

  StringChooserData? _previousData;

  NT4Topic? selectedTopic;
  NT4Topic? activeTopic;

  ComboBoxChooser({super.key, required topic, period = 0.033}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  ComboBoxChooser.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? 0.033;

    init();
  }

  @override
  void init() {
    super.init();

    optionsTopicName = '$topic/options';
    selectedTopicName = '$topic/selected';
    activeTopicName = '$topic/active';
    defaultTopicName = '$topic/default';
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !nt4Connection.isConnected) {
      return;
    }

    selectedTopic ??= nt4Connection.nt4Client
        .publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    nt4Connection.updateDataFromTopic(selectedTopic!, selected);
  }

  void publishActiveValue(String? active) {
    if (active == null || !nt4Connection.isConnected) {
      return;
    }

    bool publishTopic = activeTopic == null;

    activeTopic ??= nt4Connection.getTopicFromName(activeTopicName);

    if (activeTopic == null) {
      return;
    }

    if (publishTopic) {
      nt4Connection.nt4Client.publishTopic(activeTopic!);
    }

    nt4Connection.updateDataFromTopic(activeTopic!, active);
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();
    
    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        List<Object?> rawOptions =
            nt4Connection.getLastAnnouncedValue(optionsTopicName)
                    as List<Object?>? ??
                [];

        List<String> options = [];

        for (Object? option in rawOptions) {
          if (option == null || option is! String) {
            continue;
          }

          options.add(option);
        }

        String? active =
            nt4Connection.getLastAnnouncedValue(activeTopicName) as String?;
        if (active != null && active == '') {
          active = null;
        }

        String? selected =
            nt4Connection.getLastAnnouncedValue(selectedTopicName) as String?;
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption =
            nt4Connection.getLastAnnouncedValue(defaultTopicName) as String?;

        if (defaultOption != null && defaultOption == '') {
          defaultOption = null;
        }

        if (!nt4Connection.isConnected) {
          active = null;
          selected = null;
          defaultOption = null;
        }

        StringChooserData currentData = StringChooserData(
            options: options,
            active: active,
            defaultOption: defaultOption,
            selected: selected);

        // If a choice has been selected previously but the topic on NT has no value, publish it
        // This can happen if NT happens to restart
        if (currentData.selectedChanged(_previousData)) {
          if (selected != null && selectedChoice != selected) {
            selectedChoice = selected;
          }
        } else if (currentData.activeChanged(_previousData) || active == null) {
          if (selected == null && selectedChoice != null) {
            if (options.contains(selectedChoice!)) {
              publishSelectedValue(selectedChoice!);
            } else if (options.isNotEmpty) {
              selectedChoice = active;
            }
          }
        }

        // If nothing is selected but NT has an active value, set the selected to the NT value
        // This happens on program startup
        if (active != null && selectedChoice == null) {
          selectedChoice = active;
        }

        _previousData = currentData;

        bool showWarning = active != selectedChoice;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StringChooserDropdown(
              selected: selectedChoice,
              options: options,
              onValueChanged: (String? value) {
                publishSelectedValue(value);

                selectedChoice = value;
              },
            ),
            const SizedBox(width: 5),
            (showWarning)
                ? const Tooltip(
                    message:
                        'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                    child: Icon(Icons.priority_high, color: Colors.red),
                  )
                : const Icon(Icons.check, color: Colors.green),
          ],
        );
      },
    );
  }
}

class StringChooserData {
  final List<String> options;
  final String? active;
  final String? defaultOption;
  final String? selected;

  const StringChooserData(
      {required this.options,
      required this.active,
      required this.defaultOption,
      required this.selected});

  bool optionsChanged(StringChooserData? other) {
    return options != other?.options;
  }

  bool activeChanged(StringChooserData? other) {
    return active != other?.active;
  }

  bool defaultOptionChanged(StringChooserData? other) {
    return defaultOption != other?.defaultOption;
  }

  bool selectedChanged(StringChooserData? other) {
    // print('$selected\t${other?.selected}');
    return selected != other?.selected;
  }
}

class _StringChooserDropdown extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String? value) onValueChanged;

  const _StringChooserDropdown({
    required this.options,
    required this.onValueChanged,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: DropdownButton(
          value: selected,
          items: options.map((String option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: onValueChanged),
    );
  }
}
