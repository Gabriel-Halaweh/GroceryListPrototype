# Grocery & Recipe Planner

*"My mission is to create tools that leverage modern technology in a way that empowers individuals, democratizes knowledge, and brings happiness to everyone."*

Grocery & Recipe Planner (GroceryList v2) is a comprehensive, feature-rich grocery shopping and recipe management application built with Flutter. It features dynamic physics-based animated backgrounds, custom unit conversion relationships, fuzzy search auto-completion, and local data backup import/export features.

## App Showcase

### 📅 Main Hub & Settings
| **Main Menu** | **Settings** | **Convert Measurements** |
| :---: | :---: | :---: |
| <img src="Screenshots/MainMenu.jpg" height="400" alt="Main Menu" /> | <img src="Screenshots/Settings.jpg" height="400" alt="Settings" /> | <img src="Screenshots/ConvertMeasurments.jpg" height="400" alt="Convert Measurements" /> |

### 🛒 Grocery Shopping
| **Grocery List** | **Add to List** | **Create & Add Groceries** |
| :---: | :---: | :---: |
| <img src="Screenshots/GroceryList.jpg" height="400" alt="Grocery List" /> | <img src="Screenshots/AddToList.jpg" height="400" alt="Add to List" /> | <img src="Screenshots/CreateAndAddGroceries.jpg" height="400" alt="Ingredients Panel" /> |

### 🍳 Recipes & Cooking
| **Recipes Overview** | **Read Recipe** |
| :---: | :---: |
| <img src="Screenshots/Recipies.jpg" height="400" alt="Recipes Overview" /> | <img src="Screenshots/ReadRecipie.jpg" height="400" alt="Read Recipe" /> |

## Project Status

**This is a personal project.** It was built to serve specific personal grocery planning and cooking needs. The codebase is provided here "as is" for reference, but there is no active development, and **no future updates are planned.**

## Codebase Structure & File Descriptions

The `lib` directory is structured as a flat folder containing the following Dart source files:

* [main.dart](main.dart) - Application entry point. Handles Firebase initialization for Web/Windows platforms and launches the main application.
* [screen_main.dart](screen_main.dart) - The core application interface, orchestrating the main menu panel layout, page navigation, and panels for Grocery Lists, Recipes, Ingredients, Measurements/Calculator, and Settings.
* [grocerylist.dart](grocerylist.dart) - Contains the data model classes and logic for managing grocery list items, tags, active lists, archived lists, and templates.
* [ingredient.dart](ingredient.dart) - Defines the data models for ingredients, tag info, and custom store tag categories.
* [recipe.dart](recipe.dart) - Models recipe definitions, rating scores, ingredient sections, preparation steps, and custom tags.
* [measurements.dart](measurements.dart) - Handles unit conversions, custom unit definitions, and conversion ratios.
* [fuzzy_search.dart](fuzzy_search.dart) - Implements local fuzzy-search scoring algorithms for ingredient lists, grocery items, and recipes.
* [background_generator.dart](background_generator.dart) - A custom physics-based widget (`MovingIconBackground`) that renders a grid of animated floating icons in the background of the main menu.

## Notes

- **Firebase Configuration:** The project uses Firebase to support sync operations. For security, all credentials and project IDs have been sanitized and replaced with placeholders (e.g. `YOUR_API_KEY`, `YOUR_APP_ID`). If you wish to build or run this project yourself, you will need to replace these placeholders in `main.dart` with your own Firebase Project configuration values.
- **Local Persistence:** Data is serialized to and from local JSON files (`grocery_lists.json`, `recipe_store.json`, `measurement_store.json`, `ingredient_store.json`) inside the application documents directory, utilizing a debounce mechanism to ensure changes are saved efficiently in the background.
