# Flutter Health fit


[![N|Solid](https://peerbits-wpengine.netdna-ssl.com/wp-content/uploads/2017/04/google-kit-healthkit-feature.jpg)](https://nodesource.com/products/nsolid)

The Flutter plugin for Apple HealthKit and Google fit.

Flutter Health fit provides access to data points from Google fit and Apple health. The plugin wraps everything in a friendly and easy to use commands.

## Supported data points:
### Body Measurments:
Sex
Date of birth
Height
weight
Body fat %
waist circumference

### Respiratory
Forced Vital Capacity
Peak Expiratory Flow Rate

### Nutrition:
Carbohydrates
Fiber
Dietary sugar
Blood glucode
Protein
Total Fat

### Activity
Dietary energy
Active energy
Resting Energy
Steps
Cycling distance
Flights climbed
walking + running distance


### Sleep
Sleep

### Heart
Heart Rate
Heart Rate Variability
walking heart rate average

### Cycle Tracking
Menstruation

### Workouts
Workouts


## Installation

- Add to `pubspec.yaml`: `flutter_health_fit`.
- Open your iOS Xcode project (Runner.xcworkspace)
- Capabilities: Enable HealthKit
- Open the `info.plist`
- Add: NSHealthUpdateUsageDescription, NSHealthShareUsageDescription.


## Example

In order to access a data point we need to request an explicit permission.
For example if we want to access steps:
```sh
if(await isStepsAuthorized()){
    UserActivityDataPointValue steps = await getStepsBySegment(startMillis, endMillis);
}
```
### UserActivityDataPointValue

| Type | Param name |
| ------ | ------ |
| double | value |
| DateTime | date |
| DateTime | endDate |
| DataPointUnit | units |
| String | sourceApp |


## License
Copyright 2022 Metaflow.co

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.