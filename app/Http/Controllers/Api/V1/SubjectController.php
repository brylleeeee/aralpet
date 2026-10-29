<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSubjectRequest;
use App\Http\Resources\SubjectResource;
use App\Models\Subject;
use Illuminate\Http\Request;

class SubjectController extends Controller
{
    // GET /api/v1/subjects
    public function index(Request $request)
    {
        $subjects = $request->user()->subjects()
            ->withCount('tasks')
            ->orderBy('name')
            ->get();

        return SubjectResource::collection($subjects);
    }

    // POST /api/v1/subjects
    public function store(StoreSubjectRequest $request)
    {
        $subject = $request->user()->subjects()->create($request->validated());

        return (new SubjectResource($subject))->response()->setStatusCode(201);
    }

    // PUT /api/v1/subjects/{subject}
    public function update(StoreSubjectRequest $request, Subject $subject)
    {
        $this->authorize('update', $subject);

        $subject->update($request->validated());

        return new SubjectResource($subject);
    }

    // DELETE /api/v1/subjects/{subject}
    public function destroy(Subject $subject)
    {
        $this->authorize('delete', $subject);

        $subject->delete();   // its tasks become unassigned (subject_id = null)

        return response()->noContent();
    }
}