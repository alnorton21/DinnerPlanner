# DinnerPlanner
Flutter app to help plan meals throughout the week

TODO
1) Add in dark mode
2) Add in a local cache system using SQLlite that will store changes to the database locally. The cache should then sync with the Supabase database periodically. 
3) Add categories to the meals that can be filtered for easy searching: "Breakfast", "Lunch", "Dinner", "Snack", "Main", "Side"
4) Need to overhaul the Add Meal screen:
    a) Get rid of the importing of recipies from url or pasted text. 
    b) User should be prompted of the following
        b1) Meal Name
        b2) Servings
        b3) Category (Can be multiple)
        b4) Ingredients
            -) Allow user to type in ingredient name and information manually first. Provide a button that will trigger the scan barcode for an ingredient to grab information this way
            -) Get rid of the "Food Database" and the USDA API link for this. Take this feature away
            -) When searching for ingredients that exist, let it take me to a new screen that will list the ingredients cleanly. When the user selects the ingredient, it shows the details and the user can select it. Selecting the ingredient takes you back to the add meal screen to continue putting ingredients into the meal
        b5) Add a photo - should just come from phone picture
        b6) Add a url (Store the website where the reciepe came from)
        b7) Save Meal
    c) I want this screen to be more compact. Sleeker design