const { z, ZodError } = require('zod');

/**
 * Express middleware factory that validates req.body against a Zod schema.
 * On success the parsed (and possibly stripped/coerced) data is written back
 * to req.body. On failure a 400 response with field-level errors is returned.
 */
function validate(schema) {
  return (req, res, next) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const fieldErrors = {};
        err.errors.forEach((e) => {
          const path = e.path.join('.');
          if (!fieldErrors[path]) fieldErrors[path] = [];
          fieldErrors[path].push(e.message);
        });
        return res.status(400).json({
          message: 'Validation failed.',
          code: 'VALIDATION_ERROR',
          fieldErrors,
        });
      }
      next(err);
    }
  };
}

// ── Zod schemas used by auth routes ──────────────────────────────────────────
const schemas = {
  register: z.object({
    fullName: z.string().min(1, 'Full name is required').optional(),
    name: z.string().min(1, 'Name is required').optional(),
    email: z.string().email('Invalid email'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
  }),
  login: z.object({
    email: z.string().email('Invalid email'),
    password: z.string().min(1, 'Password is required'),
  }),
  updateProfile: z.object({
    name: z.string().optional(),
    fullName: z.string().optional(),
    avatarColor: z.string().optional(),
    baseCurrency: z.string().optional(),
    monthlyIncomeGoal: z.number().optional(),
    phone: z.string().optional(),
  }),
};

module.exports = validate;
module.exports.schemas = schemas;
