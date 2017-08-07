R.objc
======

[![Version](https://img.shields.io/cocoapods/v/R.objc.svg?style=flat)](http://cocoapods.org/pods/R.objc)
[![License](https://img.shields.io/cocoapods/l/R.objc.svg?style=flat)](http://cocoapods.org/pods/R.objc)
[![Platform](https://img.shields.io/cocoapods/p/R.objc.svg?style=flat)](http://cocoapods.org/pods/R.objc)

![](https://github.com/SysdataSpA/R.objc/blob/master/R.objc_example.gif)

Introduction
------------

Freely inspired by [R.swift](https://github.com/mac-cain13/R.swift) (Thank you,
guys!): get autocompleted localizable strings, asset catalogue images names and
storyboard objects.

You can have:

-   **Compile time check**: no more incorrect strings that make your app crash
    at runtime

-   **Autocompletion**: never have to guess that image name again

Installation
------------

[CocoaPods](http://cocoapods.org/) is the recommended way of installation, as
this avoids including any binary files into your project.

### Cocoapods

1.  Add `pod 'R.objc'` to your [Podfile](http://cocoapods.org/#get_started) and
    run `pod install`

2.  In XCode, click on your project in the Project Navigator

3.  Choose your target under `TARGETS`, click the `Build Phases` tab and add
    a `New Run Script Phase` by clicking the little plus icon in the top left

4.  Drag the new `Run Script` phase **above** the `Compile Sources` phase,
    expand it and paste the following script: 

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    "${PODS_ROOT}/R.objc/Robjc" -p "$SRCROOT"
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    (after -p option, you have to specify the root folder of your project, from
    where to scan your code)

5.  Build your project; in Finder you will now see `R.h` and `R.m` files in
    the `$SRCROOT` folder: drag them into your project and **uncheck** `Copy
    items if needed`

6.  Repeat point 3 and 4 for every target in your project

### Manual

1.  Download latest version from the [releases
    section](https://github.com/SysdataSpA/R.objc/releases)

2.  Unzip in a folder anywhere you want.

3.  In XCode, click on your project in the Project Navigator

4.  Choose your target under `TARGETS`, click the `Build Phases` tab and add
    a `New Run Script Phase` by clicking the little plus icon in the top left

5.  Drag the new `Run Script` phase **above** the `Compile Sources` phase,
    expand it and paste the following script: 

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    "<path to the unzipped folder>/Robjc" -p "$SRCROOT"
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    (we suggest to unzip the folder somewhere within your project folder, in
    order to use the `$SRCROOT` shortcut for the path. **Don't add anything to
    your Xcode project, or it won't build anymore**) (after -p option, you have
    to specify the root folder of your project, from where to scan your code)

6.  Build your project; in Finder you will now see `R.h` and `R.m` files in
    the `$SRCROOT` folder: drag them into your project and **uncheck** `Copy
    items if needed`

7.  Repeat point 3 and 4 for every target in your project


 

At every build, the generated file will update automatically and there's no need
to do anything.

Normally, you would write code like this:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[self.buttonProceed setTitle:NSLocalizedString(@"home_proceed", nil) forState:UIControlStateNormal];
self.welcomeLabel.text = [NSString stringWithFormat:NSLocalizedString(@"home_title_welcome", nil), @"John"]; //"hello %@"
self.radioButtonImageView.image = selected ? [UIImage imageNamed:@"checkedRadioButton"] : [UIImage imageNamed:@"uncheckedRadioButton"];
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now you can write

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[self.buttonProceed setTitle:R.string.localizable.homeProceed forState:UIControlStateNormal];
self.welcomeLabel.text = [R.string.localizable homeTitleWelcome:@"John"];
self.radioButtonImageView.image = selected ? R.image.checkedRadioButton : R.image.uncheckedRadioButton;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### Available command line options

You can add these options to customize R.objc behaviour:

-   `-p` (or `--path`): **MANDATORY** path to the root of the project or from where you want the scan to begin

-   `-e` (or `--excluded`): excluded dir path; all dirs within this path will be excluded; you can use `-e` option more than once

-   `-v` (or `--verbose`): verbose logging

-   `-s` (or `--sysdata`): for internal use only

-   `-r` (or `--refactor`): R.objc will replace all occurrences of NSLocalizedString with the correct `R.string` reference

-   `--skip-strings`: jump the strings step

-   `--skip-images`: jump the images step

-   `--skip-themes`: jump the themes step

-   `--skip-storyboards`: jump the storyboards step

-   `--skip-segues`: jump the segues step


What can you do?
----------------

### Localizable strings

You can access localized strings with compile time checked keys usign keypath

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
R.string.localizable.commonWarning
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The keypath is composed like this: `R.string.<string_file_name>.<string_key>`

If you check the documentation of the string (alt+click) you'll see the original
key and all the localized values

You can access localized strings containing a string with format, passing
directly parameters and obtaining the composed value

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[R.string.localizable alertMessage:@"username" value2:4.7];
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The methods is named like the key of the localized string with parameter 1
implicit; all other parameters are named value and numbered progressively.
Formats in the string are mapped by the objects the represent (eg. `%f` is
mapped as a `double`, `%@` ad an `id`)

### Images

All images will be mapped, those in an asset catalogue and those outside.

You can access by

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
R.image.navbarLogo
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You'll get a `UIImage*` directly.

### Storyboards

All storyboards in the bundle will be mapped in a
`R.storyboard.<storyboard_name>` path. You'll have an

`instantiateInitialViewController` method and a method to instantiate a view
controller for every storyboard identifier found.

Example:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[R.storyboard.main instantiateInitialViewController];
[R.storyboard.main loginViewController];
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### Segues

Like storyboards, in the segue object you'll find a list of all view controllers
which are source of a segue. Starting from them, you can access their segues and
get the segue identifier or perform segue passing source and sender objects

Example:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
R.segue.myViewController.goToNextSegue.identifier // identifier of the segue
[R.segue.myViewController.goToNextSegue.identifier performWithSource:self sender:userInfo]; // perform segue
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### Themes

If you are using [Giotto Theme Manager](https://github.com/SysdataSpA/Giotto), R.objc will search for theme_*.plist files in your project. You can then access to all your constants and styles.

Example:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[R.theme.styles.myStyle applyTo:self]; // apply the style MyStyle to object self
R.theme.constants.COLOR_TEXT_LIGHT // reference to a constant in the theme
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 

Contribute
----------

We'll love contributions, fell free to fork and submit pull requests for
additional generators or optimizations; for any question or idea write to
team.mobile[AT]sysdata.it
