# Overview

This doc describes requirements for a new app that will provide help for artists, specifically oil painters to start with. It will provide both AI and non-AI features to help the user throughout the painting process, including:

* Prep: Preparing reference photos, including cropping, minor editing, filters, adding gridlines, viewing in grayscale with limited colors, prepping photos for printing, and AI advice for creating the painting
* In-progress: Feedback during the painting process, including AI feedback, overlay with the reference, and viewing in grayscale
* Completion: On completing, it will help take and crop photos of your final painting, and can give AI-based suggestions for finishing touches or what to do next time, and can help you post to Instagram or other apps.

It will also provide a notebook feature in which users can log their final paintings along with reference photos, in-progress photos, and notes.
It will allow integration with major LLMs, such as Claude and ChatGPT, as well as with sources of photos (Google Photos and your phone camera) and with places to post (such as Instagram).

This will be an app only, not a service.

Android support is the first priority, followed by macOS, iOS, and web support.

Data can be synced between the app on different devices. The user might do the prep work on their MacBook, then use a phone for in-progress work, then switch back to the laptop for posting to social media and recording notes.

The working name is "Filbert Paint Studio", abbreviated as "Filbert".

# Walkthrough of typical usage

The user is an oil painter who is creating a new painting. They start by opening the app, where they see a list of past projects and an option to create a new project. (A project usually corresponds to a single painting.) They choose to start a new project (rather than continue an existing one), which takes them to the project screen. They're given options to select:

* A reference photo: This can be selected from the device they're using, or from google photos. Or they can choose to take a new photo with their camera, or they can leave this blank.
* Aspect ratio and/or size: Users can select either an aspect ratio or a size (in inches or cm). Common sizes and aspect ratios will be shown, or they can enter their own.
* Project name: It will default to the date (plus a number if there are already projects with that name), but can the customized.
* Beginning notes: Optionally, the user can add some notes about the painting before they begin, such as goals, focus, style, etc. This can be just for their own info, but it can also be used when asking AI for help.

When a photo is selected or viewed (such as the referent photo), they're taken to the photo screen. By default, the photo is full-screen with some very minimal UI for opening a menu and for exiting. Opening the menu gives a number of options:

* crop/rotate: 
	* By default, it will crop to the aspect ratio for the project.
	* Common aspect ratios and freeform will also be available.
	* Also, an "auto-crop" feature will be used for cropping photos of paintings in progress. This will automatically detect the edge of the canvas and crop and rotate as necessary.
* add gridlines
* view in grayscale
* view in limited colors
* compare:
	* Compare this photo to the reference (or to any other photo in the project.)
	* Comparison shows the photos overlayed on top of each other with adjustable transparency.
* prep for printing
	* Allows users to print either exactly the same size as the paintings, or another size. The painting may be larger than available paper sizes, in which case the photo can be split up into separate print jobs and the user can tape it together. The user might have their own printer, but also might use Kinkos or some other service.
* ask AI:
	* The user can select among a set of pre-canned prompts, or write their own.
	* They'll have an option to include the reference photo as well.
	* After making these selections, the app will send the images and prompt to the AI (which may be in another app)

The user might use their MacBook to create the project, enter initial info, select a reference photo, and prepare it for printing. Once they move to actual painting, they're more likely to use their phone.

During the painting process, the may take several photos along the way to add to the project. The auto-crop feature can be used to quickly crop it, and then they may view in grayscale to check values, compare with the reference, or send a query to AI to get feedback.

Once they are done with the painting, they'll take one more photo, crop it, mark it as the final painting in the app, then share to Instagram to create a post. They can select to share just the final photo, or include the reference or any of the other photos from the project.

The user might then switch back to their laptop to enter in some final notes about the project.

# Principles

The app will focus on ease of use. Users only need to use the parts of that app that are useful to them. For example, some users might not want any LLM integration, and some might not have a reference photo. Some will not sync their data between devices. Maybe a user only wants to use it for the auto-crop features, or for print preparation, in which case the app must be very easy to use for just these features.

# Other functionality

* Projects can be deleted.
* Images within a project can be deleted.
* Any image edits (cropping, grayscale, gridlines) can be undone. The original image is retained.
* When syncing data between devices, it is possible (but should be rare) that local changes have been made to the same project on different devices. In the case of images added to each, just merge the set of images. In the case of data conflicts, as the user which version to use, and suggest using the most recently updated one.

