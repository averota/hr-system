export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      company_level_rules_current: {
        Row: {
          company_id: number | null
          level_code: string | null
          level_id: number | null
          level_name_en: string | null
          level_name_km: string | null
          level_rank: number | null
          parent_level_code: string | null
          parent_level_id: number | null
          parent_level_name_en: string | null
          parent_level_name_km: string | null
          rule_id: number | null
          tree: string | null
          valid_from: string | null
        }
        Relationships: []
      }
      hierarchy_levels: {
        Row: {
          can_be_root: boolean | null
          code: string | null
          is_required: boolean | null
          level_id: number | null
          name_en: string | null
          name_km: string | null
          rank: number | null
          tree: string | null
        }
        Insert: {
          can_be_root?: boolean | null
          code?: string | null
          is_required?: boolean | null
          level_id?: number | null
          name_en?: string | null
          name_km?: string | null
          rank?: number | null
          tree?: string | null
        }
        Update: {
          can_be_root?: boolean | null
          code?: string | null
          is_required?: boolean | null
          level_id?: number | null
          name_en?: string | null
          name_km?: string | null
          rank?: number | null
          tree?: string | null
        }
        Relationships: []
      }
      job_positions_current: {
        Row: {
          company_id: number | null
          department_id: number | null
          job_position_id: number | null
          name_en: string | null
          name_km: string | null
          valid_from: string | null
        }
        Insert: {
          company_id?: number | null
          department_id?: number | null
          job_position_id?: number | null
          name_en?: string | null
          name_km?: string | null
          valid_from?: string | null
        }
        Update: {
          company_id?: number | null
          department_id?: number | null
          job_position_id?: number | null
          name_en?: string | null
          name_km?: string | null
          valid_from?: string | null
        }
        Relationships: []
      }
      org_unit_departments_current: {
        Row: {
          company_id: number | null
          department_id: number | null
          eligibility_id: number | null
          org_unit_id: number | null
          valid_from: string | null
        }
        Insert: {
          company_id?: number | null
          department_id?: number | null
          eligibility_id?: number | null
          org_unit_id?: number | null
          valid_from?: string | null
        }
        Update: {
          company_id?: number | null
          department_id?: number | null
          eligibility_id?: number | null
          org_unit_id?: number | null
          valid_from?: string | null
        }
        Relationships: []
      }
      org_units_current: {
        Row: {
          company_id: number | null
          level_code: string | null
          level_id: number | null
          level_name_en: string | null
          level_name_km: string | null
          level_rank: number | null
          name_en: string | null
          name_km: string | null
          parent_unit_id: number | null
          unit_id: number | null
          valid_from: string | null
        }
        Relationships: []
      }
      parent_companies: {
        Row: {
          company_id: number | null
          is_active: boolean | null
          name_en: string | null
          name_km: string | null
          tenant_id: number | null
        }
        Insert: {
          company_id?: number | null
          is_active?: boolean | null
          name_en?: string | null
          name_km?: string | null
          tenant_id?: number | null
        }
        Update: {
          company_id?: number | null
          is_active?: boolean | null
          name_en?: string | null
          name_km?: string | null
          tenant_id?: number | null
        }
        Relationships: []
      }
      pos_units_current: {
        Row: {
          company_id: number | null
          level_code: string | null
          level_id: number | null
          level_name_en: string | null
          level_name_km: string | null
          level_rank: number | null
          name_en: string | null
          name_km: string | null
          parent_unit_id: number | null
          unit_id: number | null
          valid_from: string | null
        }
        Relationships: []
      }
      position_allocations_current: {
        Row: {
          allocation_id: number | null
          approved_headcount: number | null
          company_id: number | null
          department_id: number | null
          department_name_en: string | null
          department_name_km: string | null
          job_name_en: string | null
          job_name_km: string | null
          job_position_id: number | null
          org_unit_id: number | null
          org_unit_name_en: string | null
          org_unit_name_km: string | null
          pos_level_code: string | null
          pos_unit_id: number | null
          pos_unit_name_en: string | null
          pos_unit_name_km: string | null
          valid_from: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      add_department_listing: {
        Args: {
          p_company_id: number
          p_department_id: number
          p_org_unit_id: number
          p_start_date?: string
        }
        Returns: number
      }
      change_allocation_headcount: {
        Args: {
          p_allocation_id: number
          p_company_id: number
          p_effective_date?: string
          p_new_headcount: number
        }
        Returns: number
      }
      check_permissions: {
        Args: {
          p_company_id: number
          p_permission_code: string
          p_targets?: Json
        }
        Returns: {
          allowed: boolean
          department_id: number
          org_unit_id: number
        }[]
      }
      close_allocation: {
        Args: {
          p_allocation_id: number
          p_close_date?: string
          p_company_id: number
        }
        Returns: undefined
      }
      close_job_position: {
        Args: { p_close_date?: string; p_company_id: number; p_job_id: number }
        Returns: undefined
      }
      close_org_unit: {
        Args: { p_close_date?: string; p_company_id: number; p_unit_id: number }
        Returns: undefined
      }
      close_pos_unit: {
        Args: { p_close_date?: string; p_company_id: number; p_unit_id: number }
        Returns: undefined
      }
      create_allocation: {
        Args: {
          p_company_id: number
          p_headcount: number
          p_job_position_id: number
          p_org_unit_id: number
          p_pos_unit_id: number
          p_start_date?: string
        }
        Returns: number
      }
      create_job_position: {
        Args: {
          p_company_id: number
          p_department_id: number
          p_name_en: string
          p_name_km?: string
        }
        Returns: number
      }
      create_org_unit: {
        Args: {
          p_company_id: number
          p_level_id: number
          p_name_en: string
          p_name_km?: string
          p_parent_unit_id: number
        }
        Returns: number
      }
      create_pos_unit: {
        Args: {
          p_company_id: number
          p_level_id: number
          p_name_en: string
          p_name_km?: string
          p_parent_unit_id: number
        }
        Returns: number
      }
      disable_level_rule: {
        Args: { p_close_date?: string; p_company_id: number; p_rule_id: number }
        Returns: undefined
      }
      eligible_departments: {
        Args: { p_company_id: number; p_org_unit_id: number }
        Returns: {
          level_code: string
          level_id: number
          name_en: string
          name_km: string
          unit_id: number
        }[]
      }
      eligible_jobs: {
        Args: {
          p_company_id: number
          p_department_id: number
          p_org_unit_id: number
        }
        Returns: {
          job_position_id: number
          name_en: string
          name_km: string
        }[]
      }
      enable_level_rule: {
        Args: {
          p_company_id: number
          p_level_id: number
          p_parent_level_id?: number
        }
        Returns: number
      }
      org_options: {
        Args: { p_company_id: number; p_parent_unit_id?: number }
        Returns: {
          level_code: string
          level_id: number
          name_en: string
          name_km: string
          unit_id: number
        }[]
      }
      pos_options: {
        Args: { p_company_id: number; p_parent_unit_id: number }
        Returns: {
          level_code: string
          level_id: number
          name_en: string
          name_km: string
          unit_id: number
        }[]
      }
      remove_department_listing: {
        Args: {
          p_close_date?: string
          p_company_id: number
          p_department_id: number
          p_org_unit_id: number
        }
        Returns: undefined
      }
      rename_job_position: {
        Args: {
          p_company_id: number
          p_job_id: number
          p_name_en: string
          p_name_km?: string
        }
        Returns: undefined
      }
      rename_org_unit: {
        Args: {
          p_company_id: number
          p_name_en: string
          p_name_km?: string
          p_unit_id: number
        }
        Returns: undefined
      }
      rename_pos_unit: {
        Args: {
          p_company_id: number
          p_name_en: string
          p_name_km?: string
          p_unit_id: number
        }
        Returns: undefined
      }
      reorg_org_unit: {
        Args: {
          p_company_id: number
          p_effective_date?: string
          p_new_parent_id: number
          p_unit_id: number
        }
        Returns: undefined
      }
      reorg_pos_unit: {
        Args: {
          p_company_id: number
          p_effective_date?: string
          p_new_parent_id: number
          p_unit_id: number
        }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
