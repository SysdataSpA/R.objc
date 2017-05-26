R.objc
======

Introduction
------------

Freely inspired by [R.swift](https://github.com/mac-cain13/R.swift) (Thank you,
guys!): get autocompleted localizable strings and asset catalogue images names.

You can have:

-   **Compile time check**: no more incorrect strings that make your app crash
    at runtime

-   **Autocompletion**: never have to guess that image name again

Installation
------------

[CocoaPods](http://cocoapods.org/) is the recommended way of installation, as
this avoids including any binary files into your project.

1.  Add `pod 'R.objc'` to your [Podfile](http://cocoapods.org/#get_started) and
    run `pod install`

2.  In XCode, click on your project in the Project Navigator

3.  Choose your target under `TARGETS`, click the `Build Phases` tab and add
    a `New Run Script Phase` by clicking the little plus icon in the top left

4.  Drag the new `Run Script` phase **above** the `Compile Sources` phase,
    expand it and paste the following script: `"$SRCROOT/rswift" "$SRCROOT"`

5.  Build your project, in Finder you will now see a `R.generated.swift` in
    the `$SRCROOT`-folder, drag the `R.generated.swift` files into your project
    and **uncheck** `Copy items if needed`

6.  Repeat point 3 and 4 for every target in your project

 

At every build, the generated file will update automatically and there's no need
to do anything.

Normally, you would write code like this:

`[self.buttonProceed setTitle:NSLocalizedString(@"home_proceed", nil)
forState:UIControlStateNormal];`

`self.welcomeLabel.text = [NSString
stringWithFormat:NSLocalizedString(@"home_title_welcome", nil), @"John"];
//"hello %@"`

`self.radioButtonImageView.image = selected ? [UIImage
imageNamed:@"checkedRadioButton"] : [UIImage
imageNamed:@"uncheckedRadioButton"];`

Now you can write

`[self.buttonProceed setTitle:R.string.localizable.homeProceed
forState:UIControlStateNormal];`

`self.welcomeLabel.text = [R.string.localizable homeTitleWelcome:@"John"];`

`self.radioButtonImageView.image = selected ? R.image.checkedRadioButton :
R.image.uncheckedRadioButton;`

Contribute
----------

We'll love contributions, fell free to fork and submit pull requests for
additional generators or optimizations; for any question or idea write to
team.mobile[AT]sysdata.it
