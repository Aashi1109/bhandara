import { onUploadComplete } from "@/features/media/controller";
import { asyncHandler } from "@/middlewares";
import { Router } from "express";

const router = Router();

router.post("/on-upload-complete", asyncHandler(onUploadComplete));

export default router;
