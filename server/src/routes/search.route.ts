import { Router } from "express";
import { SearchController } from "@features/search";
import { validateSuggestionsRequest } from "@features/search/validation";
import { validateRequest } from "@middlewares/validation";

const router = Router();

/**
 * @route   GET /api/search
 * @desc    Perform a comprehensive search across events, users, and tags
 * @access  Public
 */
router.get("/", SearchController.search);

/**
 * @route   GET /api/search/suggestions
 * @desc    Get search suggestions based on query
 * @access  Public
 */
router.get("/suggestions", validateRequest(validateSuggestionsRequest), SearchController.getSuggestions);

/**
 * @route   GET /api/search/options
 * @desc    Get available search filters and options
 * @access  Public
 */
router.get("/options", SearchController.getSearchOptions);

export default router;