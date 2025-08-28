import { EQueryOperator } from "@/definitions/enums";
import { SimpleFilter } from "@/supabase";

export const formQueryFromObject = <T extends Record<string, any>>(
  obj: Record<string, any>,
  operator: EQueryOperator = EQueryOperator.Eq
) => {
  return Object.entries(obj).map(([key, value]) => ({
    column: key as keyof T,
    operator,
    value,
  })) as (SimpleFilter & { column: keyof T })[];
};
