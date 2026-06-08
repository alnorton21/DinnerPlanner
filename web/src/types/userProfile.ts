export interface UserProfile {
  userId: string
  displayName: string
  calorieGoal: number
  proteinGoal: number
  carbGoal: number
  fatGoal: number
  darkMode: boolean
}

export function userProfileFromJson(json: any): UserProfile {
  return {
    userId: json.user_id,
    displayName: json.display_name ?? '',
    calorieGoal: Number(json.calorie_goal ?? 2000),
    proteinGoal: Number(json.protein_goal ?? 150),
    carbGoal: Number(json.carb_goal ?? 250),
    fatGoal: Number(json.fat_goal ?? 65),
    darkMode: Boolean(json.dark_mode ?? false),
  }
}

export function userProfileToJson(profile: UserProfile): Record<string, unknown> {
  return {
    user_id: profile.userId,
    display_name: profile.displayName,
    calorie_goal: profile.calorieGoal,
    protein_goal: profile.proteinGoal,
    carb_goal: profile.carbGoal,
    fat_goal: profile.fatGoal,
    dark_mode: profile.darkMode,
  }
}
