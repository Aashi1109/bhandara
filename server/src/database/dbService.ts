import {
  Attributes,
  Model,
  ModelStatic,
  Op,
  Sequelize,
  Transaction,
} from "sequelize";
import { getDBConnection } from "@connections/db";
import { EQueryOperator } from "@/definitions/enums";

type SimpleFilter = { column: string; operator: EQueryOperator; value: any };

export default class DBService {
  private sequelize: Sequelize;
  constructor() {
    this.sequelize = getDBConnection();
  }

  private buildWhere(filters: SimpleFilter[] = []) {
    const where: any = {};
    for (const { column, operator, value } of filters) {
      switch (operator) {
        case EQueryOperator.Eq:
          where[column] = value;
          break;
        case EQueryOperator.Neq:
          where[column] = { [Op.ne]: value };
          break;
        case EQueryOperator.Gt:
          where[column] = { [Op.gt]: value };
          break;
        case EQueryOperator.Gte:
          where[column] = { [Op.gte]: value };
          break;
        case EQueryOperator.Lt:
          where[column] = { [Op.lt]: value };
          break;
        case EQueryOperator.Lte:
          where[column] = { [Op.lte]: value };
          break;
        case EQueryOperator.Like:
          where[column] = { [Op.like]: value };
          break;
        case EQueryOperator.ILike:
          where[column] = { [Op.iLike]: value };
          break;
        case EQueryOperator.In:
          where[column] = { [Op.in]: value as any[] };
          break;
        case EQueryOperator.Is:
          where[column] = { [Op.is]: value };
          break;
        default:
          where[column] = value;
      }
    }
    return where;
  }

  async query<T extends Model>(
    model: ModelStatic<T>,
    {
      query = [],
      select,
      modifyOptions,
      count,
    }: {
      query?: SimpleFilter[];
      select?: string;
      modifyOptions?: (opts: any) => any;
      count?: boolean;
    }
  ): Promise<{ data: T[]; count: number | null; error: any }> {
    let options: any = { where: this.buildWhere(query) };
    if (select) options.attributes = select.split(",").map((s) => s.trim());
    if (modifyOptions) options = modifyOptions(options) || options;

    if (count) {
      const res = await model.findAndCountAll(options);
      return { data: res.rows as T[], count: res.count, error: null };
    }
    const data = await model.findAll(options);
    return { data: data as T[], count: null, error: null };
  }

  async insert<T extends Model>(
    model: ModelStatic<T>,
    data: any
  ): Promise<{ data: T; error: any }> {
    const res = await model.create(data as any);
    return { data: res.toJSON() as T, error: null };
  }

  async updateById<T extends Model>(
    model: ModelStatic<T>,
    id: string,
    data: any
  ): Promise<{ data: T | null; error: any; count: number }> {
    const [count, rows] = await model.update(data, {
      where: { id: id as Attributes<T> },
      returning: true,
    });
    return { data: (rows[0] as T) || null, error: null, count };
  }

  async deleteById<T extends Model>(
    model: ModelStatic<T>,
    id: string
  ): Promise<{ data: T | null; error: any }> {
    const row = await model.findByPk(id);
    if (!row) return { data: null, error: null };
    await (row as any).destroy();
    return { data: row.toJSON() as T, error: null };
  }

  async deleteByQuery<T extends Model>(
    model: ModelStatic<T>,
    filters: SimpleFilter[],
    single = false
  ): Promise<{ data: T | null; error: any }> {
    const where = this.buildWhere(filters);
    if (single) {
      const row = await model.findOne({ where });
      if (!row) return { data: null, error: null };
      await row.destroy();
      return { data: row.toJSON() as T, error: null };
    }
    await model.destroy({ where });
    return { data: null, error: null };
  }

  async transaction<T>(callback: (t: Transaction) => Promise<T>) {
    return this.sequelize.transaction(callback);
  }
}
